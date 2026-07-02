#include "PipelineEvents.h"

#include <ctime>
#include <fstream>
#include <string>

#include "ProductInfo.h"
#include "RageLog.h"
#include "ver.h"

namespace PipelineEvents {

std::string JsonEscape(const std::string& value) {
  std::string escaped;
  escaped.reserve(value.size() + 8);
  for (char ch : value) {
    switch (ch) {
      case '\\':
        escaped += "\\\\";
        break;
      case '"':
        escaped += "\\\"";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += ch;
        break;
    }
  }
  return escaped;
}

std::string TimestampUtc() {
  time_t now = time(nullptr);
  tm utc;
#if defined(_WIN32)
  gmtime_s(&utc, &now);
#else
  gmtime_r(&now, &utc);
#endif
  char timestamp[32];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return timestamp;
}

std::string SessionId() {
  static const std::string sessionId =
      std::string("itgmania-pipeline-") + TimestampUtc();
  return sessionId;
}

std::string EventFilePath(const std::string& eventDir) {
  time_t now = time(nullptr);
  tm utc;
#if defined(_WIN32)
  gmtime_s(&utc, &now);
#else
  gmtime_r(&now, &utc);
#endif
  char date[16];
  strftime(date, sizeof(date), "%Y%m%d", &utc);

  std::string path = eventDir;
  if (!path.empty() && path.back() != '/' && path.back() != '\\') {
    path += "/";
  }
  path += "events-";
  path += date;
  path += ".jsonl";
  return path;
}

std::string ProductVersion() {
  return std::string(PRODUCT_FAMILY) + product_version;
}

std::string SourceJson() {
  return std::string("{\"install\":\"patched-cli\",\"stepmaniaVersion\":\"") +
         JsonEscape(ProductVersion()) +
         "\",\"capabilityProfile\":\"itgmania-pipeline\","
         "\"capabilities\":{\"sidecarVersion\":\"0.1.0\","
         "\"stepmaniaVersion\":\"" +
         JsonEscape(ProductVersion()) +
         "\",\"profile\":\"itgmania-pipeline\","
         "\"events\":[\"session_start\",\"song_start\",\"judgment\","
         "\"combo_milestone\",\"song_end\",\"stage_result\",\"error\"],"
         "\"features\":{\"jsonlEventBus\":true,\"latestStateSnapshot\":true,"
         "\"writeErrorLog\":true,\"gameplayOverlayHook\":true,"
         "\"evaluationOverlayHook\":true,\"themeBootstrapLaunch\":true,"
         "\"baseGamePipelineLaunch\":true}}}";
}

std::string CapabilitiesJson() {
  const std::string product = PRODUCT_ID;
  return std::string("{\"schemaVersion\":1,\"game\":\"stepmania\",\"product\":\"") +
         JsonEscape(product) + "\",\"productVersion\":\"" +
         JsonEscape(ProductVersion()) + "\",\"gitHash\":\"" +
         JsonEscape(::sm_version_git_hash) +
         "\",\"capabilityProfile\":\"itgmania-pipeline\","
         "\"events\":[\"session_start\",\"song_start\",\"judgment\","
         "\"combo_milestone\",\"song_end\",\"stage_result\",\"error\"],"
         "\"pipelineCli\":{\"supported\":true,\"version\":1,"
         "\"args\":[\"--pipeline-song\",\"--pipeline-song-dir\","
         "\"--pipeline-screen\",\"--pipeline-difficulty\","
         "\"--pipeline-autoplay\",\"--pipeline-event-dir\"]}}";
}

bool AppendEvent(
    const std::string& eventDir, const std::string& eventType,
    const std::string& payloadJson, const char* warnContext) {
  if (eventDir.empty()) {
    return false;
  }

  std::ofstream out(EventFilePath(eventDir), std::ios::app);
  if (!out) {
    LOG->Warn(
        "%s could not open pipeline event dir: %s", warnContext,
        eventDir.c_str());
    return false;
  }

  out << "{\"schemaVersion\":1,\"game\":\"stepmania\",\"eventType\":\""
      << JsonEscape(eventType) << "\",\"sentAtUtc\":\"" << TimestampUtc()
      << "\",\"sessionId\":\"" << JsonEscape(SessionId())
      << "\",\"source\":" << SourceJson() << ",\"payload\":" << payloadJson
      << "}\n";
  return true;
}

}  // namespace PipelineEvents
