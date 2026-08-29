import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../.github/workflows/mission-spine-signed-mobile-build.yml', import.meta.url),
  'utf8',
);

test('main signing jobs are isolated from the branch-only dispatcher', () => {
  assert.match(
    workflow,
    /  sign-android:\n    if: github\.ref == 'refs\/heads\/main'/,
  );
  assert.match(
    workflow,
    /  publish-bundle:\n    name: Publish signed Android bundle\n    needs: sign-android\n    if: github\.ref == 'refs\/heads\/main'/,
  );
  assert.match(
    workflow,
    /  dispatch-signed-mobile:\n    if: github\.ref == 'refs\/heads\/chore\/prod26r6-signed-mobile-dispatch'/,
  );
});

test('dispatcher is exact, Actions-only, and fail-closed', () => {
  const dispatcher = workflow.split('  dispatch-signed-mobile:\n', 2)[1];
  assert.ok(dispatcher);
  for (const fragment of [
    'permissions:\n      actions: write\n      contents: read',
    'RELEASE_ID: ms-20260829-prod26r6',
    'SOURCE_SHA: edc2c56f695eaad6d5e494bab81d5b5db4427e14',
    'test "$GITHUB_ACTOR" = "VelkaressiaBlutkrone"',
    'test "$GITHUB_TRIGGERING_ACTOR" = "VelkaressiaBlutkrone"',
    'test "$GITHUB_RUN_ATTEMPT" = "1"',
    '"ref": "main"',
    'actions/workflows/mission-spine-signed-mobile-build.yml/dispatches',
    'test "$inner_actor" = "github-actions[bot]"',
    'test "$inner_triggering_actor" = "github-actions[bot]"',
    'actions/runs/$inner_run_id/cancel',
  ]) {
    assert.ok(dispatcher.includes(fragment), fragment);
  }
  for (const forbidden of [
    'contents: write',
    'administration: write',
    'pull-requests: write',
    '--force',
  ]) {
    assert.ok(!dispatcher.includes(forbidden), forbidden);
  }
});
