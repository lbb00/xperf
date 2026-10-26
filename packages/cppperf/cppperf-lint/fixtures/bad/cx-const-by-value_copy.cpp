#include <string>
#include <vector>

int touch_text(const std::string text) {
  return text.empty() ? 0 : static_cast<int>(text[0]);
}

int touch_nums(const std::vector<int> nums, int scale) {
  return nums.empty() ? scale : nums[0];
}

int touch_east_text(std::string const text) {
  return text.empty() ? 0 : static_cast<int>(text[0]);
}

int touch_east_nums(std::vector<int> const nums) {
  return nums.empty() ? 0 : nums[0];
}

int sum_rows(const std::vector<std::string>& rows) {
  int n = 0;
  for (const std::string row : rows) n += static_cast<int>(row.size());
  return n;
}

int sum_groups(const std::vector<std::vector<int>>& groups) {
  int n = 0;
  for (const std::vector<int> group : groups) n += group.empty() ? 0 : group[0];
  return n;
}
