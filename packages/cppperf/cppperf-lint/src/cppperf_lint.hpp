#pragma once
#include <string>
#include <vector>

struct Finding {
  std::string rule;
  std::string path;
  int line = 0;
  std::string message;
};

std::vector<Finding> scan_file(const std::string& path);
std::vector<Finding> scan_path(const std::string& root);
