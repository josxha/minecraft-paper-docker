import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';

const PAPER_API = "https://papermc.io/api/v2/projects/paper";
const DOCKER_TAG_API = "https://registry.hub.docker.com/v1/repositories/josxha/minecraft-paper/tags";

bool DRY_RUN = false;
bool FORCE_BUILDS = false;

main(List<String> args) async {
  for (var arg in args) {
    switch (arg) {
      case "force":
        FORCE_BUILDS = true;
        break;
      case "dry-run":
        DRY_RUN = true;
        break;
      default:
        throw "Unknown argument: '$arg'";
    }
  }

  var minecraftVersions = await getMinecraftVersions();

  var dockerImageTags = await getDockerImageTags();

  for (var minecraftVersion in minecraftVersions) {
    print("[$minecraftVersion] Checking updates for minecraft version");

    // get paper build ids for the minecraft version
    var paperBuilds = await getPaperBuilds(minecraftVersion);
    int counter = 0;
    for(var paperBuild in paperBuilds.reversed) {
      if (counter++ >= 1) {
        print("[$minecraftVersion] Maximum amount of recent builds for this minecraft version reached.");
        break;
      }
      print("[$minecraftVersion-$paperBuild] Check if an docker image exists for the paper build ...");
      if (dockerImageTags.contains("$minecraftVersion-$paperBuild")) {
        // image already exists
        if (FORCE_BUILDS) {
          print("[$minecraftVersion-$paperBuild] Image exists but force update enabled.");
        } else {
          print("[$minecraftVersion-$paperBuild] Image exists, skip build.");
          continue;
        }
      }

      // image doesn't exist yet
      // download paper build
      print("[$minecraftVersion-$paperBuild] Build and push image");
      var jarName = await getJarName(minecraftVersion, paperBuild);
      if (DRY_RUN) {
        //var response = await get(Uri.parse("$PAPER_API/versions/$minecraftVersion/builds/$paperBuild/downloads/$jarName"));
        await File("paper.jar").writeAsString("Dry run by the dev branch. Not the real downloaded jar file.", mode: FileMode.write);
      } else {
        var response = await get(Uri.parse("$PAPER_API/versions/$minecraftVersion/builds/$paperBuild/downloads/$jarName"));
        await File("paper.jar").writeAsBytes(response.bodyBytes, mode: FileMode.write);
      }
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
      await dockerBuildPushRemove(tags);
      print("[$minecraftVersion-$paperBuild] Built, pushed and cleaned up successfully!");
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

Future<void> dockerBuildPushRemove(List<String> tags) async {
  var args = [
    "buildx", "build", ".",
    "--push",
    "--platform", "linux/arm64,linux/amd64",
  ];
  tags.forEach((String tag) {
    args.addAll([
      "--tag",
      "josxha/minecraft-paper:$tag",
    ]);
  });
  if (DRY_RUN)
    return;
  var taskResult = Process.runSync("docker", args);
  if (taskResult.exitCode != 0) {
    print(taskResult.stdout);
    print(taskResult.stderr);
    throw Exception("Couldn't run docker build for $tags.");
  }
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
  var jsonList = jsonDecode(response.body) as List;
  return jsonList.map((listElement) => listElement["name"] as String).toList();
}

Future<List<String>> getMinecraftVersions() async {
  var response = await get(Uri.parse(PAPER_API));
  List versions = jsonDecode(response.body)["versions"];
  return versions.cast<String>();
}
