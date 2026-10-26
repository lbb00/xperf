/**
 * An internal abstraction for the built-in modules.
 * Class fields and once-init must not be jp-alloc-in-loop.
 */
class Realm {
  static map = new Map();
  init() {
    this.cache = new Set();
  }
}
module.exports = { Realm };
