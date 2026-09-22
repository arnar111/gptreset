export function memoryKV(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    async get(key) {
      return map.has(key) ? map.get(key) : null;
    },
    async put(key, value) {
      map.set(key, String(value));
    },
    async delete(key) {
      map.delete(key);
    },
    async list({ prefix = "" } = {}) {
      const keys = [...map.keys()].filter((key) => key.startsWith(prefix)).map((name) => ({ name }));
      return { keys, list_complete: true };
    },
  };
}
