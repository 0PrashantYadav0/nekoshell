import { defineConfig } from 'vitest/config'

// The unit tests are plain Node: they cover src/lib, which has no DOM in it.
// Vite itself is still in the loop, because the docs module reads the Markdown
// under src/content with import.meta.glob.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
})
