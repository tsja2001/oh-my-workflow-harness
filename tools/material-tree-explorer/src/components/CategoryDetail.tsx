import { useMemo } from 'react';
import { CheckCircleOutlined, CopyOutlined, DiffOutlined, InfoCircleOutlined } from '@ant-design/icons';
import {
  App as AntdApp,
  Button,
  Card,
  Descriptions,
  Empty,
  Space,
  Table,
  Tabs,
  Tag,
  Typography,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import type { CategoryForest, CategoryNode, Environment } from '../types';
import { compareCategoryForests } from '../utils/tree';
import MaterialExplorer from './MaterialExplorer';

interface Props {
  environment: Environment;
  otherEnvironment: Environment;
  forest: CategoryForest;
  otherForest: CategoryForest;
  selected?: CategoryNode;
}

const statusTag = (state: string) => (
  <Tag color={state === '1' ? 'green' : 'default'} icon={state === '1' ? <CheckCircleOutlined /> : undefined}>
    {state === '1' ? '启用' : state === '0' ? '停用' : `状态 ${state || '未知'}`}
  </Tag>
);

function CategoryOverview({ selected }: { selected: CategoryNode }) {
  const { message } = AntdApp.useApp();
  const copy = async (text: string) => {
    await navigator.clipboard.writeText(text);
    message.success('已复制');
  };
  const childColumns: ColumnsType<CategoryNode> = [
    { title: '编码', dataIndex: 'classCode', width: 120 },
    { title: '名称', dataIndex: 'className' },
    { title: '层级', dataIndex: 'level', width: 80, render: (value: number) => `${value} 级` },
    { title: '状态', dataIndex: 'state', width: 90, render: statusTag },
    { title: '后代数', dataIndex: 'descendantCount', width: 90 },
    { title: '是否末级', dataIndex: 'isLeaf', width: 100, render: (value: boolean) => value ? <Tag color="blue">末级</Tag> : '否' },
  ];

  return (
    <div className="detail-overview">
      <div className="category-heading">
        <div>
          <Space wrap>
            <Typography.Title level={3}>{selected.classCode} · {selected.className}</Typography.Title>
            <Tag color="blue">{selected.level || '?'} 级</Tag>
            {selected.isLeaf && <Tag color="purple">末级</Tag>}
            {statusTag(selected.state)}
            {selected.orphan && <Tag color="red">父级断链</Tag>}
          </Space>
          <Typography.Text type="secondary">{selected.pathNames.join(' / ')}</Typography.Text>
        </div>
        <Space>
          <Button icon={<CopyOutlined />} onClick={() => void copy(selected.classCode)}>复制编码</Button>
          <Button icon={<CopyOutlined />} onClick={() => void copy(selected.pathNames.join(' / '))}>复制路径</Button>
        </Space>
      </div>

      <Descriptions bordered size="small" column={{ xs: 1, sm: 2, xl: 3 }}>
        <Descriptions.Item label="类目编码">{selected.classCode}</Descriptions.Item>
        <Descriptions.Item label="类目名称">{selected.className}</Descriptions.Item>
        <Descriptions.Item label="父级">{selected.parentClassCode === '0' ? '根节点' : `${selected.parentClassCode} ${selected.parentClassName}`}</Descriptions.Item>
        <Descriptions.Item label="编码路径">{selected.pathCodes.join(' → ')}</Descriptions.Item>
        <Descriptions.Item label="直接子级">{selected.children.length}</Descriptions.Item>
        <Descriptions.Item label="全部后代">{selected.descendantCount}</Descriptions.Item>
        <Descriptions.Item label="采购方式">{selected.purchaseTypeDesc || selected.purchaseType || '-'}</Descriptions.Item>
        <Descriptions.Item label="默认单位">{selected.unit ? `${selected.unit}${selected.unitCode ? ` (${selected.unitCode})` : ''}` : '-'}</Descriptions.Item>
        <Descriptions.Item label="数据来源">{selected.dataSource || '-'}</Descriptions.Item>
        <Descriptions.Item label="同步时间">{selected.upperTime ? new Date(selected.upperTime).toLocaleString('zh-CN') : '-'}</Descriptions.Item>
        <Descriptions.Item label="类目说明" span={2}>{selected.description || '-'}</Descriptions.Item>
      </Descriptions>

      <div className="subsection-title">
        <Typography.Title level={5}>直接下级（{selected.children.length}）</Typography.Title>
        <Typography.Text type="secondary">末级不是固定第四级，而是“没有直接下级”的节点。</Typography.Text>
      </div>
      <Table<CategoryNode>
        rowKey="classCode"
        size="small"
        columns={childColumns}
        dataSource={selected.children}
        pagination={{ pageSize: 10, hideOnSinglePage: true }}
        locale={{ emptyText: '这是末级类目，没有下级' }}
      />
    </div>
  );
}

function DifferencePanel({
  environment,
  otherEnvironment,
  forest,
  otherForest,
  selected,
}: Props) {
  const differences = useMemo(() => compareCategoryForests(forest, otherForest), [forest, otherForest]);
  const matching = selected ? otherForest.byCode.get(selected.classCode) : undefined;
  const rows = [
    ...differences.onlyCurrent.map((node) => ({ key: `current-${node.classCode}`, type: `仅 ${environment.toUpperCase()}`, code: node.classCode, current: node.className, other: '-' })),
    ...differences.onlyOther.map((node) => ({ key: `other-${node.classCode}`, type: `仅 ${otherEnvironment.toUpperCase()}`, code: node.classCode, current: '-', other: node.className })),
    ...differences.nameChanges.map(({ current, other }) => ({ key: `name-${current.classCode}`, type: '名称不同', code: current.classCode, current: current.className, other: other.className })),
    ...differences.stateChanges.map(({ current, other }) => ({ key: `state-${current.classCode}`, type: '状态不同', code: current.classCode, current: current.state === '1' ? '启用' : '停用', other: other.state === '1' ? '启用' : '停用' })),
  ];

  return (
    <div className="difference-panel">
      <div className="difference-stats">
        <Card size="small"><strong>{differences.onlyCurrent.length}</strong><span>仅 {environment.toUpperCase()}</span></Card>
        <Card size="small"><strong>{differences.onlyOther.length}</strong><span>仅 {otherEnvironment.toUpperCase()}</span></Card>
        <Card size="small"><strong>{differences.nameChanges.length}</strong><span>名称不同</span></Card>
        <Card size="small"><strong>{differences.stateChanges.length}</strong><span>状态不同</span></Card>
      </div>

      {selected && (
        <Card size="small" title={<Space><InfoCircleOutlined />当前所选节点对比</Space>}>
          {matching ? (
            <Descriptions size="small" column={2} bordered>
              <Descriptions.Item label={`${environment.toUpperCase()} 名称`}>{selected.className}</Descriptions.Item>
              <Descriptions.Item label={`${otherEnvironment.toUpperCase()} 名称`}>{matching.className}</Descriptions.Item>
              <Descriptions.Item label={`${environment.toUpperCase()} 状态`}>{statusTag(selected.state)}</Descriptions.Item>
              <Descriptions.Item label={`${otherEnvironment.toUpperCase()} 状态`}>{statusTag(matching.state)}</Descriptions.Item>
              <Descriptions.Item label={`${environment.toUpperCase()} 路径`}>{selected.pathNames.join(' / ')}</Descriptions.Item>
              <Descriptions.Item label={`${otherEnvironment.toUpperCase()} 路径`}>{matching.pathNames.join(' / ')}</Descriptions.Item>
            </Descriptions>
          ) : (
            <Typography.Text type="danger">{selected.classCode} 在 {otherEnvironment.toUpperCase()} 不存在</Typography.Text>
          )}
        </Card>
      )}

      <Table
        className="difference-table"
        size="small"
        rowKey="key"
        dataSource={rows}
        columns={[
          { title: '差异类型', dataIndex: 'type', width: 120, render: (value: string) => <Tag color="orange">{value}</Tag> },
          { title: '类目编码', dataIndex: 'code', width: 120 },
          { title: environment.toUpperCase(), dataIndex: 'current' },
          { title: otherEnvironment.toUpperCase(), dataIndex: 'other' },
        ]}
        pagination={{ pageSize: 20, showSizeChanger: true, pageSizeOptions: [20, 50, 100] }}
        locale={{ emptyText: '两个环境没有发现类目差异' }}
      />
    </div>
  );
}

export default function CategoryDetail(props: Props) {
  const { environment, selected } = props;
  if (!selected) {
    return <Card className="detail-card"><Empty description="请先从左侧选择一个类目" /></Card>;
  }
  return (
    <Card className="detail-card" title={<Space><DiffOutlined />类目与物料详情</Space>}>
      <Tabs
        defaultActiveKey="overview"
        destroyOnHidden={false}
        items={[
          { key: 'overview', label: '类目概览', children: <CategoryOverview selected={selected} /> },
          { key: 'materials', label: '具体物料', children: <MaterialExplorer environment={environment} selected={selected} /> },
          { key: 'difference', label: '环境差异', children: <DifferencePanel {...props} /> },
        ]}
      />
    </Card>
  );
}
