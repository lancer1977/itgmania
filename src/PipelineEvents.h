#ifndef PIPELINE_EVENTS_H
#define PIPELINE_EVENTS_H

#include <string>

namespace PipelineEvents {

std::string JsonEscape(const std::string& value);
std::string TimestampUtc();
std::string SessionId();
std::string EventFilePath(const std::string& eventDir);
std::string ProductVersion();
std::string SourceJson();
std::string CapabilitiesJson();
bool AppendEvent(
    const std::string& eventDir, const std::string& eventType,
    const std::string& payloadJson, const char* warnContext);

}  // namespace PipelineEvents

#endif
