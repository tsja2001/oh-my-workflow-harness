import { useEffect, useMemo, useState } from 'react';
import {
  ApartmentOutlined,
  CompressOutlined,
  ExpandOutlined,
  FileOutlined,
  FolderOpenOutlined,
  SearchOutlined,
} from '@ant-design/icons';
import { Button, Card, Input, Select, Space, Switch, Tag, Tree, Typography } from 'antd';
import type { DataNode } from 'antd/es/tree';
import type { CategoryFilters, CategoryForest, CategoryNode } from '../types';
import { collectTreeKeys, filterCategoryTree } from '../utils/tree';

interface Props {
  forest: CategoryForest;
  selectedCode?: string;
  onSelect: (code?: string) => void;
}

const levelColors = ['default', 'blue', 'cyan', 'purple', 'magenta'];

function toTreeData(nodes: CategoryNode[], keyword: string): DataNode[] {
  const lowerKeyword = keyword.trim().toLocaleLowerCase();
  return nodes.map((node) => {
    const text = `${node.classCode} ${node.className}`;
    const index = lowerKeyword ? text.toLocaleLowerCase().indexOf(lowerKeyword) : -1;
    const title = index >= 0 ? (
      <span>
        {text.slice(0, index)}<mark>{text.slice(index, index + lowerKeyword.length)}</mark>{text.slice(index + lowerKeyword.length)}
        <Tag color={levelColors[node.level]}>{node.level || '?'}级</Tag>
      </span>
    ) : (
      <span>
        <span className={node.state === '1' ? '' : 'muted-node'}>{text}</span>
        <Tag color={levelColors[node.level]}>{node.level || '?'}级</Tag>
        {node.orphan && <Tag color="red">断链</Tag>}
      </span>
    );
    return {
      key: node.classCode,
      title,
      icon: node.isLeaf ? <FileOutlined /> : <FolderOpenOutlined />,
      children: toTreeData(node.children, keyword),
    };
  });
}

export default function CategoryTreePanel({ forest, selectedCode, onSelect }: Props) {
  const [filters, setFilters] = useState<CategoryFilters>({
    keyword: '',
    level: 'all',
    state: 'all',
    leafOnly: false,
  });
  const filtered = useMemo(() => filterCategoryTree(forest.roots, filters), [forest, filters]);
  const allKeys = useMemo(() => collectTreeKeys(filtered), [filtered]);
  const [expandedKeys, setExpandedKeys] = useState<React.Key[]>([]);
  const treeData = useMemo(() => toTreeData(filtered, filters.keyword), [filtered, filters.keyword]);

  useEffect(() => {
    if (filters.keyword || filters.level !== 'all' || filters.leafOnly) {
      setExpandedKeys(allKeys);
    }
  }, [allKeys, filters.keyword, filters.level, filters.leafOnly]);

  return (
    <Card
      className="tree-card"
      title={<Space><ApartmentOutlined />完整类目树</Space>}
      extra={<Typography.Text type="secondary">显示 {allKeys.length} / {forest.stats.total}</Typography.Text>}
    >
      <div className="tree-filters">
        <Input
          allowClear
          value={filters.keyword}
          prefix={<SearchOutlined />}
          placeholder="搜编码、名称或完整路径"
          onChange={(event) => setFilters((current) => ({ ...current, keyword: event.target.value }))}
        />
        <div className="filter-row">
          <Select
            value={filters.level}
            options={[
              { label: '全部层级', value: 'all' },
              { label: '一级（2 位）', value: 1 },
              { label: '二级（4 位）', value: 2 },
              { label: '三级（6 位）', value: 3 },
              { label: '四级（8 位）', value: 4 },
            ]}
            onChange={(level) => setFilters((current) => ({ ...current, level }))}
          />
          <Select
            value={filters.state}
            options={[
              { label: '全部状态', value: 'all' },
              { label: '仅启用', value: '1' },
              { label: '仅停用', value: '0' },
            ]}
            onChange={(state) => setFilters((current) => ({ ...current, state }))}
          />
        </div>
        <div className="filter-row between">
          <Space><Switch checked={filters.leafOnly} onChange={(leafOnly) => setFilters((current) => ({ ...current, leafOnly }))} />只看末级</Space>
          <Space.Compact>
            <Button icon={<ExpandOutlined />} onClick={() => setExpandedKeys(allKeys)}>展开</Button>
            <Button icon={<CompressOutlined />} onClick={() => setExpandedKeys([])}>收起</Button>
          </Space.Compact>
        </div>
      </div>
      {treeData.length ? (
        <Tree
          showIcon
          showLine
          blockNode
          virtual
          height={690}
          treeData={treeData}
          selectedKeys={selectedCode ? [selectedCode] : []}
          expandedKeys={expandedKeys}
          onExpand={setExpandedKeys}
          onSelect={(keys) => onSelect(keys[0] ? String(keys[0]) : undefined)}
        />
      ) : (
        <div className="tree-empty">没有符合条件的类目</div>
      )}
    </Card>
  );
}
