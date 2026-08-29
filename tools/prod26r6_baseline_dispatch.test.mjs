import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../.github/workflows/et13-baseline-approval.yml', import.meta.url),
  'utf8',
);

test('protected baseline approval is isolated from the branch dispatcher', () => {
  assert.match(
    workflow,
    /  approve-baseline:\n    if: github\.ref == 'refs\/heads\/main'/,
  );
  assert.match(
    workflow,
    /  dispatch-baseline:\n    if: github\.ref == 'refs\/heads\/chore\/prod26r8-baseline-dispatch'/,
  );
});

test('baseline dispatcher pins every raw review coordinate and fails closed', () => {
  const dispatcher = workflow.split('  dispatch-baseline:\n', 2)[1];
  assert.ok(dispatcher);
  for (const fragment of [
    'permissions:\n      actions: write\n      contents: read',
    'RELEASE_ID: ms-20260829-prod26r8',
    'SOURCE_SHA: edc2c56f695eaad6d5e494bab81d5b5db4427e14',
    'RAW_RUN_ID: "33245572930"',
    'RAW_RUN_ATTEMPT: "1"',
    'RAW_ARTIFACT_ID: "9712811778"',
    'RAW_ARTIFACT_DIGEST: sha256:adc66fd00d5d6d9ead00209f3a9c3c268b7c1da029426a0df4b9702b9ed4cef6',
    'RAW_WORKFLOW_SHA256: 001654acab3847e3cdce750e84cf18315b8853f60a43c1289a34a14ae939843f',
    'test "$GITHUB_ACTOR" = "VelkaressiaBlutkrone"',
    'test "$GITHUB_TRIGGERING_ACTOR" = "VelkaressiaBlutkrone"',
    'test "$GITHUB_RUN_ATTEMPT" = "1"',
    '"ref": "main"',
    'actions/workflows/et13-baseline-approval.yml/dispatches',
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
