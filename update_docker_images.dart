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
    int counter = 0;
    for(var paperBuild in paperBuilds.reversed) {
      print("[$minecraftVersion] Check if an docker image exists for the paper build $paperBuild...");
      if (dockerImageTags.contains(paperBuild) && args[1] != 'force') {
        // image already exists
        print("Image $minecraftVersion-$paperBuild exists.");
        continue;
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
            tags.add("${getMajorVersion(minecraftVersion)}-latest");
        }
      } else {
        if (paperBuild == paperBuilds.last) {
          // not latest minecraft version, latest paper build
          tags.add(minecraftVersion);
          if (versionIsHighestSubversion(minecraftVersion, minecraftVersions))
            tags.add("${getMajorVersion(minecraftVersion)}-latest");
        }
      }
      await dockerBuildAndPush(tags);
      print("Built $minecraftVersion-$paperBuild!");
      counter++;
      if (counter > 5) {
        break;
      }
    }
  }
}

String getMajorVersion(String version) {
  var list = version.split(RegExp("[\.-]")); // split at . or -
  return list[0] + "." + list[1];
}

bool versionIsHighestSubversion(String version, List<String> allVersions) {
  bool indexOfVersionReached = false;
  var majorVersion = getMajorVersion(version);
  for (var tmpVersion in allVersions) {
    // check if other mayor version
    if (getMajorVersion(tmpVersion) == majorVersion) {
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
  var buildResult = dockerBuild(tags);
  print(buildResult.stdout);
  print(buildResult.stderr);
  if (buildResult.exitCode != 0)
    throw Exception("Couldn't run docker build for $tags.");
  for (var tag in tags) {
    var pushResult = dockerPush(tag);
    if (pushResult.exitCode != 0)
      throw Exception("Couldn't run docker push for $tag.");
    var removeResult = dockerRemove(tag);
    if (removeResult.exitCode != 0)
      throw Exception("Couldn't run docker remove image for $tag.");
  }
}

ProcessResult dockerBuild(List<String> tags) {
  var args = ["build", "."];
  tags.forEach((String tag) {
    args.addAll([
      "--tag",
      "josxha/minecraft-paper:$tag",
    ]);
  });
  return Process.runSync("docker", args);
}

ProcessResult dockerRemove(String tag) {
  return Process.runSync("docker", [
    "rmi",
    "josxha/minecraft-paper:$tag",
  ]);
}

ProcessResult dockerPush(String tag) {
  return Process.runSync("docker", [
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