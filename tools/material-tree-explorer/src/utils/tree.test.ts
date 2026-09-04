import { describe, expect, it } from 'vitest';
import type { CategoryRecord } from '../types';
import {
  buildCategoryForest,
  compareCategoryForests,
  filterCategoryTree,
  levelFromCode,
} from './tree';

const record = (classCode: string, className: string, parentClassCode: string, state = '1'): CategoryRecord => ({
  classId: classCode,
  classCode,
  className,
  parentClassCode,
  parentClassName: '',
  state,
  upperTime: null,
  updateTime: null,
  unit: '',
  unitCode: '',
  purchaseType: '',
  purchaseTypeDesc: '',
  description: '',
  dataSource: 'mdm',
});

const base = [
  record('15', '金属材料', '0'),
  record('1501', '黑色金属', '15'),
  record('150101', '型材', '1501'),
  record('15010112', '螺纹钢', '150101'),
  record('9999', '断链节点', '99', '0'),
];

describe('物料类目树', () => {
  it('按编码长度识别层级', () => {
    expect(['15', '1501', '150101', '15010112'].map(levelFromCode)).toEqual([1, 2, 3, 4]);
    expect(levelFromCode('123')).toBe(0);
  });

  it('组装路径、末级、后代和断链', () => {
    const forest = buildCategoryForest(base);
    const leaf = forest.byCode.get('15010112');
    expect(leaf?.pathNames).toEqual(['金属材料', '黑色金属', '型材', '螺纹钢']);
    expect(leaf?.isLeaf).toBe(true);
    expect(forest.byCode.get('15')?.descendantCount).toBe(3);
    expect(forest.stats.orphan).toBe(1);
  });

  it('搜索时保留命中节点的完整祖先链', () => {
    const forest = buildCategoryForest(base);
    const filtered = filterCategoryTree(forest.roots, {
      keyword: '螺纹钢',
      level: 'all',
      state: 'all',
      leafOnly: false,
    });
    expect(filtered[0].children[0].children[0].children[0].classCode).toBe('15010112');
  });

  it('识别两套环境的缺失、改名和状态差异', () => {
    const current = buildCategoryForest(base);
    const other = buildCategoryForest([
      record('15', '金属类', '0'),
      record('1501', '黑色金属', '15', '0'),
      record('16', '建筑材料', '0'),
    ]);
    const diff = compareCategoryForests(current, other);
    expect(diff.onlyCurrent.map((item) => item.classCode)).toContain('15010112');
    expect(diff.onlyOther.map((item) => item.classCode)).toEqual(['16']);
    expect(diff.nameChanges).toHaveLength(1);
    expect(diff.stateChanges).toHaveLength(1);
  });
});
