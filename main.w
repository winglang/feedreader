bring cloud;
bring util;
bring http;
bring expect;

struct GithubAtomFeed {
  id: str;
  updated: str;
}
struct GithubAtom {
  feed: GithubAtomFeed;
}

class Feedreader {
  extern "./feed.mjs" pub static inflight parseAtomFeed(): GithubAtom;
}

let githubToken = new cloud.Secret(name: "github-token");
let bucket = new cloud.Bucket();

bucket.onCreate(inflight () => {
  let token = githubToken.value();
  let owner = "winglang";
  let repo = "examples";
  log("Triggering run in https://github.com/{owner}/{repo}");
  let result = http.post("https://api.github.com/repos/{owner}/{repo}/dispatches",
    headers: {
      "Authorization": "Bearer {token}",
      "Accept": "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: Json.stringify({
      "event_type": "feedreader",
      "client_payload": {}
    }),
  );

  log("Result: ${result.ok} ${result.status} ${result.body}");
});

// This cron schedule runs every 2 minutes
let schedule = new cloud.Schedule(cron: "0/2 * ? * *");

let scheduleHandler = inflight () => {
  let json: GithubAtom = Feedreader.parseAtomFeed();
  let id = util.sha256(json.feed.updated);
  if bucket.exists(id) {
    log("No new versions");
  } else {
    log("New versions");
    bucket.put(id, "new version ${json.feed.updated}");
  }
};

schedule.onTick(scheduleHandler);

test "parse atom feed" {
  let json = Feedreader.parseAtomFeed();
  let feedId = json.feed.id;
  expect.equal("tag:github.com,2008:https://github.com/winglang/wing/releases", feedId);
}