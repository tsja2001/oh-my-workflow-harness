import type {
  CategoryDifference,
  CategoryFilters,
  CategoryForest,
  CategoryNode,
  CategoryRecord,
} from '../types';

export function levelFromCode(code: string): number {
  const level = code.length / 2;
  return Number.isInteger(level) && level >= 1 && level <= 4 ? level : 0;
}

export function buildCategoryForest(records: CategoryRecord[]): CategoryForest {
  const duplicateCodes = records.length - new Set(records.map((item) => item.classCode)).size;
  const byCode = new Map<string, CategoryNode>();

  for (const record of records) {
    if (!record.classCode || byCode.has(record.classCode)) continue;
    byCode.set(record.classCode, {
      ...record,
      children: [],
      level: levelFromCode(record.classCode),
      isLeaf: true,
      pathCodes: [],
      pathNames: [],
      descendantCount: 0,
      orphan: false,
    });
  }

  const roots: CategoryNode[] = [];
  for (const node of byCode.values()) {
    const parent = byCode.get(node.parentClassCode);
    if (node.parentClassCode === '0') {
      roots.push(node);
    } else if (parent && parent !== node) {
      parent.children.push(node);
      parent.isLeaf = false;
    } else {
      node.orphan = true;
      roots.push(node);
    }
  }

  const visiting = new Set<string>();
  const visited = new Set<string>();
  const decorate = (node: CategoryNode, parentCodes: string[], parentNames: string[]): number => {
    if (visiting.has(node.classCode)) {
      node.orphan = true;
      return 0;
    }
    if (visited.has(node.classCode)) return node.descendantCount;
    visiting.add(node.classCode);
    node.children.sort((left, right) => left.classCode.localeCompare(right.classCode));
    node.pathCodes = [...parentCodes, node.classCode];
    node.pathNames = [...parentNames, node.className];
    let descendants = 0;
    for (const child of node.children) {
      descendants += 1 + decorate(child, node.pathCodes, node.pathNames);
    }
    node.descendantCount = descendants;
    node.isLeaf = node.children.length === 0;
    visiting.delete(node.classCode);
    visited.add(node.classCode);
    return descendants;
  };

  roots.sort((left, right) => left.classCode.localeCompare(right.classCode));
  for (const root of roots) decorate(root, [], []);

  // 异常环形数据可能不会落到根节点，仍作为孤儿根展示，避免静默丢失。
  for (const node of byCode.values()) {
    if (!visited.has(node.classCode)) {
      node.orphan = true;
      roots.push(node);
      decorate(node, [], []);
    }
  }

  const nodes = [...byCode.values()];
  const levels = { 1: 0, 2: 0, 3: 0, 4: 0 };
  for (const node of nodes) {
    if (node.level in levels) levels[node.level as 1 | 2 | 3 | 4] += 1;
  }
  return {
    roots,
    nodes,
    byCode,
    stats: {
      total: nodes.length,
      enabled: nodes.filter((node) => node.state === '1').length,
      disabled: nodes.filter((node) => node.state !== '1').length,
      leaf: nodes.filter((node) => node.isLeaf).length,
      orphan: nodes.filter((node) => node.orphan).length,
      duplicateCodes,
      levels,
    },
  };
}

function nodeMatches(node: CategoryNode, filters: CategoryFilters) {
  const keyword = filters.keyword.trim().toLocaleLowerCase();
  const keywordMatches = !keyword
    || node.classCode.toLocaleLowerCase().includes(keyword)
    || node.className.toLocaleLowerCase().includes(keyword)
    || node.pathNames.join(' / ').toLocaleLowerCase().includes(keyword);
  const levelMatches = filters.level === 'all' || node.level === filters.level;
  const stateMatches = filters.state === 'all' || node.state === filters.state;
  const leafMatches = !filters.leafOnly || node.isLeaf;
  return keywordMatches && levelMatches && stateMatches && leafMatches;
}

export function filterCategoryTree(
  roots: CategoryNode[],
  filters: CategoryFilters,
): CategoryNode[] {
  const visit = (node: CategoryNode): CategoryNode | null => {
    const children = node.children.map(visit).filter((item): item is CategoryNode => item !== null);
    if (!nodeMatches(node, filters) && children.length === 0) return null;
    return { ...node, children };
  };
  return roots.map(visit).filter((item): item is CategoryNode => item !== null);
}

export function collectTreeKeys(nodes: CategoryNode[]): string[] {
  return nodes.flatMap((node) => [node.classCode, ...collectTreeKeys(node.children)]);
}

export function compareCategoryForests(
  current: CategoryForest,
  other: CategoryForest,
): CategoryDifference {
  const onlyCurrent = current.nodes.filter((node) => !other.byCode.has(node.classCode));
  const onlyOther = other.nodes.filter((node) => !current.byCode.has(node.classCode));
  const nameChanges: CategoryDifference['nameChanges'] = [];
  const stateChanges: CategoryDifference['stateChanges'] = [];
  for (const node of current.nodes) {
    const matching = other.byCode.get(node.classCode);
    if (!matching) continue;
    if (node.className !== matching.className) nameChanges.push({ current: node, other: matching });
    if (node.state !== matching.state) stateChanges.push({ current: node, other: matching });
  }
  return { onlyCurrent, onlyOther, nameChanges, stateChanges };
}
