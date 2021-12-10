import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';

const PAPER_API = "https://papermc.io/api/v2/projects/paper";
const DOCKER_TAG_API = "https://hub.docker.com/v2/repositories/josxha/minecraft-paper/tags/";


main(List<String> args) async {
  var minecraftVersions = await getMinecraftVersions();

  var dockerImageTags = await getDockerImageTags();

  for (var minecraftVersion in minecraftVersions) {
    print("Check for Minecraft version $minecraftVersion");

    // get paper build ids for the minecraft version
    var paperBuilds = await getPaperBuilds(minecraftVersion);
    paperBuilds.reversed.forEach((paperBuild) async {
      print("[$minecraftVersion] Check if an docker image exists for the paper build $paperBuild...");
      if (dockerImageTags.contains(paperBuild) && args[1] != 'force') {
        // image already exists
        print("Image $minecraftVersion-$paperBuild exists.");
        return;
      }

      // image doesn't exist yet
      // download paper build
      print("Build and push image for $minecraftVersion-$paperBuild");
      var jarName = await getJarName(minecraftVersion, paperBuild);
      var response = await get(Uri.parse("$PAPER_API/versions/$minecraftVersion/builds/$paperBuild/downloads/$jarName"));
      await File("paper.jar").writeAsBytes(response.bodyBytes, mode: FileMode.write);
      var tags = ["$minecraftVersion-$paperBuild"];
      if (minecraftVersion == minecraftVersions.last) {
        if (paperBuild == paperBuilds.last) {
          // latest minecraft version, latest paper build
          tags.addAll([minecraftVersion, "latest"]);
          if (versionIsHighestSubversion(minecraftVersion, minecraftVersions))
            tags.add("$minecraftVersion-latest");
        }
      } else {
        if (paperBuild == paperBuilds.last) {
          // not latest minecraft version, latest paper build
          tags.add(minecraftVersion);
          if (versionIsHighestSubversion(minecraftVersion, minecraftVersions))
            tags.add("$minecraftVersion-latest");
        }
      }
      await dockerBuildAndPush(tags);
      print("Built $minecraftVersion-$paperBuild!");
    });
  }
}

bool versionIsHighestSubversion(String version, List<String> allVersions) {
  bool indexOfVersionReached = false;
  var versionList = version.split(RegExp("[\.-]")); // split at . or -
  for (var tmpVersion in allVersions) {
    var tmpVersionList = tmpVersion.split(RegExp("[\.-]")); // split at . or -

    // check if other mayor version
    if (versionList[0] != tmpVersionList[0] || versionList[1] != tmpVersionList[1]) {
      continue;
    }
    if (indexOfVersionReached)
      return false;
    if (tmpVersion == version) {
      indexOfVersionReached = true;
    }
  }
  return true;
}

Future<void> dockerBuildAndPush(List<String> tags) async {
  var buildResult = await dockerBuild(tags);
  print(buildResult.stdout);
  print(buildResult.stderr);
  if (buildResult.exitCode != 0)
    throw Exception("Couldn't run docker build for $tags.");
  var futures = tags.map((tag) => dockerPush(tag)).toList();
  var pushResults = await Future.wait(futures);
  pushResults.forEach((pushResult) {
    if (pushResult.exitCode != 0)
      throw Exception("Couldn't run docker push for $tags.");
  });
}

Future<ProcessResult> dockerBuild(List<String> tags) async {
  var args = ["docker", "build", "."];
  tags.forEach((String tag) {
    args.addAll([
      "--tag",
      "josxha/minecraft-paper:$tag",
    ]);
  });
  return Process.run("docker", args);
}

Future<ProcessResult> dockerPush(String tag) async {
  return Process.run("docker", [
    "push",
    "josxha/minecraft-paper:$tag",
  ]);
}

Future<String> getJarName(minecraftVersion, paperBuild) async {
  var response = await get(Uri.parse("$PAPER_API/versions/$minecraftVersion/builds/$paperBuild"));
  var json = jsonDecode(response.body);
  return json["downloads"]["application"]["name"];
}

Future<List<int>> getPaperBuilds(minecraftVersion) async {
  var response = await get(Uri.parse("$PAPER_API/versions/$minecraftVersion"));
  List builds = jsonDecode(response.body)["builds"];
  return builds.cast<int>();
}

Future<List<String>> getDockerImageTags() async {
  var response = await get(Uri.parse(DOCKER_TAG_API));
  var json = jsonDecode(response.body);
  var jsonList = json["results"] as List;
  return jsonList.map((listElement) => listElement["name"] as String).toList();
}

Future<List<String>> getMinecraftVersions() async {
  var response = await get(Uri.parse(PAPER_API));
  List versions = jsonDecode(response.body)["versions"];
  return versions.cast<String>();
}