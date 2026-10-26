"use strict";
/* Object/map keyed delete: jp-delete-shape OK, must NOT be jp-delete-array-hole. */
function evict(map, key) {
  delete map[key];
  return map;
}
module.exports = { evict };
