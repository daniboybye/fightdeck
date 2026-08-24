/**
 * React Native 0.87 ships its Gradle plugin as sources pinned to Kotlin 2.2, and Gradle
 * compiles that plugin against the Kotlin runtime inside its own distribution. Gradle 9.7
 * carries Kotlin 2.4, whose metadata a 2.2 compiler refuses to read, so a pristine install
 * cannot build any Android target in this app. Aligning the plugin's Kotlin with the one
 * this repository already pins is the smallest change that keeps both versions honest.
 *
 * Runs from `postinstall`, so `npm ci` on a fresh clone lands in the same state as a
 * developer machine. Idempotent: re-running it on an aligned tree does nothing.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const lockPath = join(here, '..', '..', '..', '..', 'versions.lock.toml');
const catalogPath = join(
  here,
  '..',
  'node_modules',
  '@react-native',
  'gradle-plugin',
  'gradle',
  'libs.versions.toml',
);

function pinnedKotlin() {
  const lock = readFileSync(lockPath, 'utf8');
  const android = lock.split(/^\[/m).find((section) => section.startsWith('android]'));
  const match = android?.match(/^kotlin\s*=\s*"([^"]+)"/m);
  if (!match) {
    throw new Error(`android.kotlin not found in ${lockPath}`);
  }
  return match[1];
}

function main() {
  let catalog;
  try {
    catalog = readFileSync(catalogPath, 'utf8');
  } catch {
    // Nothing to align before the dependency is on disk.
    return;
  }

  const wanted = pinnedKotlin();
  const current = catalog.match(/^kotlin\s*=\s*"([^"]+)"/m)?.[1];
  if (current === wanted) {
    return;
  }

  writeFileSync(catalogPath, catalog.replace(/^kotlin\s*=\s*"[^"]+"/m, `kotlin = "${wanted}"`));
  console.log(`Aligned @react-native/gradle-plugin Kotlin ${current} → ${wanted}`);
}

main();
