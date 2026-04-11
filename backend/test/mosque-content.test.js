import test from 'node:test';
import assert from 'node:assert/strict';

import { normalizeContentItems } from '../src/services/mosque-content.js';

test('normalizeContentItems preserves unpublished schedule and poster fields as empty', () => {
  const items = normalizeContentItems(
    [
      {
        title: 'Community Iftar',
        schedule: '',
        posterLabel: '',
        location: 'Community Hall',
        description: 'Hosted after Maghrib.'
      }
    ],
    'event'
  );

  assert.equal(items.length, 1);
  assert.equal(items[0].title, 'Community Iftar');
  assert.equal(items[0].schedule, '');
  assert.equal(items[0].posterLabel, '');
});
