import { describe, it, expect, vi } from 'vitest';

import { processTaskIpc, IpcDeps } from './ipc.js';

function makeDeps(overrides: Partial<IpcDeps> = {}): IpcDeps {
  return {
    sendMessage: vi.fn(async () => {}),
    registeredGroups: vi.fn(() => ({})),
    registerGroup: vi.fn(),
    syncGroups: vi.fn(async () => {}),
    getAvailableGroups: vi.fn(() => []),
    writeGroupsSnapshot: vi.fn(),
    onTasksChanged: vi.fn(),
    ...overrides,
  };
}

describe('processTaskIpc register_group', () => {
  it('passes priorityAccount to registerGroup', async () => {
    const deps = makeDeps();
    await processTaskIpc(
      {
        type: 'register_group',
        jid: 'group@g.us',
        name: 'Sales',
        folder: 'whatsapp_sales',
        trigger: '@Andy',
        priorityAccount: 'demo',
      },
      'main',
      true, // isMain
      deps,
    );

    expect(deps.registerGroup).toHaveBeenCalledWith(
      'group@g.us',
      expect.objectContaining({ priorityAccount: 'demo' }),
    );
  });

  it('passes undefined priorityAccount when not provided', async () => {
    const deps = makeDeps();
    await processTaskIpc(
      {
        type: 'register_group',
        jid: 'group@g.us',
        name: 'Family',
        folder: 'whatsapp_family',
        trigger: '@Andy',
      },
      'main',
      true,
      deps,
    );

    expect(deps.registerGroup).toHaveBeenCalledWith(
      'group@g.us',
      expect.objectContaining({ priorityAccount: undefined }),
    );
  });

  it('blocks register_group from non-main groups', async () => {
    const deps = makeDeps();
    await processTaskIpc(
      {
        type: 'register_group',
        jid: 'group@g.us',
        name: 'Hacker',
        folder: 'whatsapp_hacker',
        trigger: '@Andy',
        priorityAccount: 'production',
      },
      'some-group',
      false, // NOT main
      deps,
    );

    expect(deps.registerGroup).not.toHaveBeenCalled();
  });
});
