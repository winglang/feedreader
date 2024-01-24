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
  log("File in bucket created");
  let token = githubToken.value();
  let owner = "winglang";
  let repo = "examples";
  let workflowId = "wing-sdk.yml";
  let result = http.post("https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflowId}/dispatches",
    headers: {
      "Authorization": "token ${token}",
      "Accept": "application/vnd.github.v3+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: Json.stringify({
      "ref": "main",
    }),
  );

  log("Result: ${result.ok} ${result.status} ${result.body}");
});

// This cron schedule runs every minute
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