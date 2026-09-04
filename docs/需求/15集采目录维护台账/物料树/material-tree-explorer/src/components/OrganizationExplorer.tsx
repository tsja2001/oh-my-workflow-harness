import { useEffect, useMemo, useState } from 'react';
import {
  ApartmentOutlined,
  BankOutlined,
  CheckCircleOutlined,
  ClusterOutlined,
  EnvironmentOutlined,
  FolderOpenOutlined,
  ReloadOutlined,
  SearchOutlined,
  ShopOutlined,
  TableOutlined,
  TeamOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Input,
  Progress,
  Select,
  Skeleton,
  Space,
  Statistic,
  Switch,
  Table,
  Tabs,
  Tag,
  Tree,
  Typography,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import type { DataNode } from 'antd/es/tree';
import { fetchOrganizations } from '../api';
import type {
  BuSummary,
  Environment,
  NameCodeConflict,
  OrganizationAnalysis,
  OrganizationRecord,
  OrganizationResponse,
  RegionSummary,
} from '../types';
import {
  analyzeOrganizations,
  cleanText,
  organizationMatches,
  organizationsForCell,
} from '../utils/organization';

interface Props {
  environment: Environment;
  refreshToken: number;
  onLoadingChange?: (loading: boolean) => void;
}

const EMPTY_REGION_KEY = '__unassigned__';

function statusTag(state: string) {
  return state === '1'
    ? <Tag color="green" icon={<CheckCircleOutlined />}>启用</Tag>
    : <Tag>停用</Tag>;
}

function levelLabel(level: string) {
  return ({ JT: '集团/平台', GS: '集团·二级集团', BS: '企业' } as Record<string, string>)[level]
    ?? (level ? `未知层级 ${level}` : '层级为空');
}

const organizationColumns: ColumnsType<OrganizationRecord> = [
  { title: '企业编码', dataIndex: 'orgCode', width: 118, fixed: 'left' },
  { title: '企业名称', dataIndex: 'orgName', width: 260, ellipsis: true },
  { title: 'BU', dataIndex: 'belongBuCode', width: 100 },
  { title: 'BU 名称', dataIndex: 'belongBuName', width: 170, ellipsis: true, render: cleanText },
  {
    title: '区域',
    key: 'region',
    width: 210,
    render: (_, row) => row.belongPlateCode
      ? <Space size={4}><Tag color="blue">{row.belongPlateCode}</Tag><span>{cleanText(row.belongPlateName) || '名称为空'}</span></Space>
      : <Tag color="orange">未分配</Tag>,
  },
  { title: '状态', dataIndex: 'state', width: 86, render: statusTag },
  { title: '组织层级', dataIndex: 'organizationLevel', width: 125, render: levelLabel },
];

function OrganizationTable({ rows, pageSize = 10 }: { rows: OrganizationRecord[]; pageSize?: number }) {
  return (
    <Table<OrganizationRecord>
      rowKey={(row) => `${row.orgId}-${row.orgCode}`}
      size="small"
      columns={organizationColumns}
      dataSource={rows}
      scroll={{ x: 1080 }}
      pagination={{ pageSize, showSizeChanger: true, pageSizeOptions: [10, 20, 50, 100], showTotal: (total) => `共 ${total} 条` }}
      locale={{ emptyText: '没有符合条件的组织' }}
    />
  );
}

function OrganizationDetail({ organization }: { organization: OrganizationRecord }) {
  return (
    <div className="organization-detail">
      <Space wrap>
        <Typography.Title level={4}>{organization.orgCode} · {organization.orgName}</Typography.Title>
        {statusTag(organization.state)}
        <Tag color="geekblue">{levelLabel(organization.organizationLevel)}</Tag>
      </Space>
      <Descriptions bordered size="small" column={{ xs: 1, lg: 2, xl: 3 }}>
        <Descriptions.Item label="简称">{organization.shortName || '-'}</Descriptions.Item>
        <Descriptions.Item label="BU">{organization.belongBuCode ? `${organization.belongBuCode} · ${cleanText(organization.belongBuName)}` : '-'}</Descriptions.Item>
        <Descriptions.Item label="区域">{organization.belongPlateCode ? `${organization.belongPlateCode} · ${cleanText(organization.belongPlateName) || '名称为空'}` : '未分配'}</Descriptions.Item>
        <Descriptions.Item label="权限层级">{organization.authLevel || '-'}</Descriptions.Item>
        <Descriptions.Item label="组织类型">{organization.orgTypeDesc || organization.orgType || '-'}</Descriptions.Item>
        <Descriptions.Item label="业务类型">{organization.businessTypeDesc || organization.businessType || '-'}</Descriptions.Item>
        <Descriptions.Item label="所属公司">{organization.belongCompanyOrgCode ? `${organization.belongCompanyOrgCode} · ${organization.belongCompanyOrgName}` : '-'}</Descriptions.Item>
        <Descriptions.Item label="采购办公室">{organization.belongOfficeCode ? `${organization.belongOfficeCode} · ${organization.belongOfficeName}` : '-'}</Descriptions.Item>
        <Descriptions.Item label="是否区域采购">{organization.areaPurchaseDesc || (organization.areaPurchase == null ? '-' : String(organization.areaPurchase))}</Descriptions.Item>
        <Descriptions.Item label="地址" span={2}>{organization.companyAddress || '-'}</Descriptions.Item>
        <Descriptions.Item label="更新时间">{organization.updateTime ? new Date(organization.updateTime).toLocaleString('zh-CN') : '-'}</Descriptions.Item>
      </Descriptions>
    </div>
  );
}

function buOptions(analysis: OrganizationAnalysis) {
  return [
    { label: '全部 BU', value: 'all' },
    ...analysis.buGroups.map((bu) => ({ label: `${bu.code} · ${bu.name}`, value: bu.code })),
  ];
}

function regionOptions(analysis: OrganizationAnalysis) {
  return [
    { label: '全部区域', value: 'all' },
    { label: `未分配区域（${analysis.unassignedEnterprises.length}）`, value: EMPTY_REGION_KEY },
    ...analysis.regionGroups.map((region) => ({ label: `${region.code} · ${region.name}`, value: region.code })),
  ];
}

function OrganizationTreeView({ analysis }: { analysis: OrganizationAnalysis }) {
  const [keyword, setKeyword] = useState('');
  const [buCode, setBuCode] = useState('all');
  const [regionCode, setRegionCode] = useState('all');
  const [state, setState] = useState('all');
  const [selectedKey, setSelectedKey] = useState('group');
  const [expandedKeys, setExpandedKeys] = useState<React.Key[]>(['group']);

  const filteredBus = useMemo(() => analysis.buGroups
    .filter((bu) => buCode === 'all' || bu.code === buCode)
    .map((bu) => ({
      ...bu,
      enterprises: bu.enterprises.filter((organization) => (
        organizationMatches(organization, keyword)
        && (state === 'all' || organization.state === state)
        && (regionCode === 'all'
          || (regionCode === EMPTY_REGION_KEY ? !organization.belongPlateCode : cleanText(organization.belongPlateCode) === regionCode))
      )),
    }))
    .map((bu) => ({
      ...bu,
      assignedEnterprises: bu.enterprises.filter((organization) => organization.belongPlateCode && organization.belongPlateName),
      coverageRate: bu.enterprises.length
        ? bu.enterprises.filter((organization) => organization.belongPlateCode && organization.belongPlateName).length / bu.enterprises.length
        : 0,
    }))
    .filter((bu) => bu.enterprises.length > 0 || (!keyword && regionCode === 'all' && state === 'all')),
  [analysis, buCode, keyword, regionCode, state]);

  const treeData = useMemo<DataNode[]>(() => [{
    key: 'group',
    title: <Space><BankOutlined /><strong>{analysis.groupName}</strong><Tag color="geekblue">集团</Tag><Tag>{filteredBus.length} 个 BU</Tag></Space>,
    children: filteredBus.map((bu) => ({
      key: `bu:${bu.code}`,
      icon: <ApartmentOutlined />,
      title: (
        <Space size={5} wrap>
          <strong>{bu.code}</strong><span>{bu.name}</span>
          <Tag>{bu.enterprises.length} 家企业</Tag>
          <Tag color={bu.coverageRate >= 0.8 ? 'green' : bu.coverageRate ? 'gold' : 'red'}>区域 {bu.assignedEnterprises.length}/{bu.enterprises.length || 0}</Tag>
        </Space>
      ),
      children: bu.enterprises.map((organization) => ({
        key: `org:${organization.orgCode}`,
        icon: <ShopOutlined />,
        title: (
          <Space size={5} wrap>
            <span className={organization.state === '1' ? '' : 'muted-node'}>{organization.orgCode} · {organization.orgName}</span>
            {organization.belongPlateCode
              ? <Tag color="blue">{organization.belongPlateCode}</Tag>
              : <Tag color="orange">未分区域</Tag>}
          </Space>
        ),
      })),
    })),
  }], [analysis, filteredBus]);

  useEffect(() => {
    if (keyword || buCode !== 'all' || regionCode !== 'all' || state !== 'all') {
      setExpandedKeys(['group', ...filteredBus.map((bu) => `bu:${bu.code}`)]);
    }
  }, [buCode, filteredBus, keyword, regionCode, state]);

  const selectedOrganization = selectedKey.startsWith('org:')
    ? analysis.enterprises.find((item) => item.orgCode === selectedKey.slice(4))
    : undefined;
  const selectedBu = selectedKey.startsWith('bu:')
    ? analysis.buGroups.find((item) => item.code === selectedKey.slice(3))
    : undefined;

  return (
    <div className="organization-view-grid">
      <Card className="organization-tree-card" title={<Space><ApartmentOutlined />集团 → BU → 企业</Space>} extra={<Typography.Text type="secondary">企业口径：organizationLevel=BS</Typography.Text>}>
        <div className="organization-filters">
          <Input allowClear prefix={<SearchOutlined />} value={keyword} placeholder="搜企业编码、名称、BU 或区域" onChange={(event) => setKeyword(event.target.value)} />
          <Select value={buCode} options={buOptions(analysis)} showSearch optionFilterProp="label" onChange={setBuCode} />
          <Select value={regionCode} options={regionOptions(analysis)} showSearch optionFilterProp="label" onChange={setRegionCode} />
          <Select value={state} options={[{ label: '全部状态', value: 'all' }, { label: '仅启用', value: '1' }, { label: '仅停用', value: '0' }]} onChange={setState} />
        </div>
        <Tree
          showIcon
          showLine
          blockNode
          virtual
          height={650}
          treeData={treeData}
          selectedKeys={[selectedKey]}
          expandedKeys={expandedKeys}
          onExpand={setExpandedKeys}
          onSelect={(keys) => keys[0] && setSelectedKey(String(keys[0]))}
        />
      </Card>

      <Card className="organization-detail-card" title="所选节点详情">
        {selectedOrganization ? <OrganizationDetail organization={selectedOrganization} /> : selectedBu ? (
          <>
            <div className="selected-heading">
              <div><Typography.Title level={4}>{selectedBu.code} · {selectedBu.name}</Typography.Title><Typography.Text type="secondary">名称口径：{selectedBu.names.join(' / ') || '-'}</Typography.Text></div>
              <Progress type="circle" size={76} percent={Math.round(selectedBu.coverageRate * 100)} />
            </div>
            <Descriptions bordered size="small" column={3}>
              <Descriptions.Item label="企业数">{selectedBu.enterprises.length}</Descriptions.Item>
              <Descriptions.Item label="已分区域">{selectedBu.assignedEnterprises.length}</Descriptions.Item>
              <Descriptions.Item label="未分区域">{selectedBu.enterprises.length - selectedBu.assignedEnterprises.length}</Descriptions.Item>
              <Descriptions.Item label="BU 锚点组织" span={3}>{selectedBu.anchorOrganizations.map((item) => `${item.orgCode} ${item.orgName}`).join('；') || '接口中没有 GS/JT 锚点'}</Descriptions.Item>
            </Descriptions>
            <Typography.Title level={5} className="section-title">企业明细</Typography.Title>
            <OrganizationTable rows={selectedBu.enterprises} />
          </>
        ) : (
          <>
            <Alert type="info" showIcon message="组织主线与区域标签是两种关系" description="这棵树只表达集团、BU 和企业的隶属关系。区域请到“区域反向树”和“覆盖矩阵”中查看。" />
            <Table<BuSummary>
              className="section-table"
              rowKey="code"
              size="small"
              dataSource={analysis.buGroups}
              pagination={false}
              columns={[
                { title: 'BU', dataIndex: 'code', width: 90 },
                { title: '名称', dataIndex: 'name' },
                { title: '企业', key: 'enterprises', width: 80, render: (_, row) => row.enterprises.length },
                { title: '已分区域', key: 'assigned', width: 100, render: (_, row) => row.assignedEnterprises.length },
                { title: '覆盖率', key: 'coverage', width: 180, render: (_, row) => <Progress percent={Math.round(row.coverageRate * 100)} size="small" /> },
              ]}
            />
          </>
        )}
      </Card>
    </div>
  );
}

function RegionTreeView({ analysis }: { analysis: OrganizationAnalysis }) {
  const [keyword, setKeyword] = useState('');
  const [buCode, setBuCode] = useState('all');
  const [conflictOnly, setConflictOnly] = useState(false);
  const [selectedRegion, setSelectedRegion] = useState(analysis.regionGroups[0]?.code ?? EMPTY_REGION_KEY);
  const [selectedBu, setSelectedBu] = useState<string>();
  const [selectedOrganizationCode, setSelectedOrganizationCode] = useState<string>();
  const [expandedKeys, setExpandedKeys] = useState<React.Key[]>([]);

  const regionRows = useMemo(() => [
    { code: EMPTY_REGION_KEY, name: '未分配区域', names: ['未分配区域'], enterprises: analysis.unassignedEnterprises, buCodes: [...new Set(analysis.unassignedEnterprises.map((item) => item.belongBuCode))].filter(Boolean), codeNameConflict: false, enterpriseCodeMatches: [] } satisfies RegionSummary,
    ...analysis.regionGroups,
  ].filter((region) => {
    if (conflictOnly && !region.codeNameConflict) return false;
    const matchingMembers = region.enterprises.filter((organization) => organizationMatches(organization, keyword) && (buCode === 'all' || organization.belongBuCode === buCode));
    const regionMatches = `${region.code} ${region.name} ${region.names.join(' ')}`.toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase());
    return (!keyword || regionMatches || matchingMembers.length > 0) && (buCode === 'all' || matchingMembers.length > 0);
  }), [analysis, buCode, conflictOnly, keyword]);

  const treeData = useMemo<DataNode[]>(() => regionRows.map((region) => {
    const members = region.enterprises.filter((organization) => organizationMatches(organization, keyword) && (buCode === 'all' || organization.belongBuCode === buCode));
    const membersByBu = analysis.buGroups
      .map((bu) => ({ bu, members: members.filter((organization) => organization.belongBuCode === bu.code) }))
      .filter((item) => item.members.length > 0);
    return {
      key: `region:${region.code}`,
      icon: region.code === EMPTY_REGION_KEY ? <WarningOutlined /> : <EnvironmentOutlined />,
      title: <Space size={5} wrap><strong>{region.code === EMPTY_REGION_KEY ? '未分配区域' : `${region.code} · ${region.name}`}</strong><Tag color={region.code === EMPTY_REGION_KEY ? 'orange' : 'blue'}>{members.length} 家</Tag>{region.codeNameConflict && <Tag color="red">名称冲突</Tag>}</Space>,
      children: membersByBu.map(({ bu, members: buMembers }) => ({
        key: `region-bu:${region.code}:${bu.code}`,
        icon: <ApartmentOutlined />,
        title: <Space size={5}>{bu.code} · {bu.name}<Tag>{buMembers.length} 家</Tag></Space>,
        children: buMembers.map((organization) => ({
          key: `region-org:${region.code}:${bu.code}:${organization.orgCode}`,
          icon: <ShopOutlined />,
          title: `${organization.orgCode} · ${organization.orgName}`,
        })),
      })),
    };
  }), [analysis.buGroups, buCode, keyword, regionRows]);

  useEffect(() => {
    if (keyword || buCode !== 'all' || conflictOnly) {
      setExpandedKeys(treeData.flatMap((region) => [region.key, ...(region.children ?? []).map((child) => child.key)]));
    }
  }, [buCode, conflictOnly, keyword, treeData]);

  useEffect(() => {
    if (selectedRegion !== EMPTY_REGION_KEY && !analysis.regionGroups.some((item) => item.code === selectedRegion)) {
      setSelectedRegion(analysis.regionGroups[0]?.code ?? EMPTY_REGION_KEY);
      setSelectedBu(undefined);
      setSelectedOrganizationCode(undefined);
    }
  }, [analysis, selectedRegion]);

  const selectedRegionSummary = selectedRegion === EMPTY_REGION_KEY
    ? regionRows.find((item) => item.code === EMPTY_REGION_KEY)
    : analysis.regionGroups.find((item) => item.code === selectedRegion);
  const selectedMembers = (selectedRegionSummary?.enterprises ?? []).filter((item) => !selectedBu || item.belongBuCode === selectedBu);
  const selectedOrganization = selectedOrganizationCode
    ? selectedMembers.find((item) => item.orgCode === selectedOrganizationCode)
    : undefined;

  const handleSelect = (keys: React.Key[]) => {
    if (!keys[0]) return;
    const parts = String(keys[0]).split(':');
    if (parts[0] === 'region') {
      setSelectedRegion(parts[1]);
      setSelectedBu(undefined);
      setSelectedOrganizationCode(undefined);
    } else if (parts[0] === 'region-bu') {
      setSelectedRegion(parts[1]);
      setSelectedBu(parts[2]);
      setSelectedOrganizationCode(undefined);
    } else if (parts[0] === 'region-org') {
      setSelectedRegion(parts[1]);
      setSelectedBu(parts[2]);
      setSelectedOrganizationCode(parts.slice(3).join(':'));
    }
  };

  return (
    <div className="organization-view-grid">
      <Card className="organization-tree-card" title={<Space><EnvironmentOutlined />区域 → BU → 企业</Space>} extra={<Typography.Text type="secondary">按企业区域标签反向整理</Typography.Text>}>
        <Alert className="region-explain" type="warning" showIcon message="区域不是组织树层级" description="这里把企业身上的区域标签反向组成树，仅用于看覆盖关系。" />
        <div className="organization-filters region-filters">
          <Input allowClear prefix={<SearchOutlined />} value={keyword} placeholder="搜区域、BU 或企业" onChange={(event) => setKeyword(event.target.value)} />
          <Select value={buCode} options={buOptions(analysis)} showSearch optionFilterProp="label" onChange={setBuCode} />
          <Space><Switch checked={conflictOnly} onChange={setConflictOnly} />只看名称冲突</Space>
        </div>
        <Tree
          showIcon
          showLine
          blockNode
          virtual
          height={590}
          treeData={treeData}
          expandedKeys={expandedKeys}
          onExpand={setExpandedKeys}
          onSelect={handleSelect}
        />
      </Card>
      <Card className="organization-detail-card" title="区域成员详情">
        {selectedOrganization ? <OrganizationDetail organization={selectedOrganization} /> : selectedRegionSummary ? (
          <>
            <div className="selected-heading">
              <div>
                <Typography.Title level={4}>{selectedRegionSummary.code === EMPTY_REGION_KEY ? '未分配区域' : `${selectedRegionSummary.code} · ${selectedRegionSummary.name}`}</Typography.Title>
                <Typography.Text type={selectedRegionSummary.codeNameConflict ? 'danger' : 'secondary'}>
                  {selectedRegionSummary.code === EMPTY_REGION_KEY ? '这些企业没有所属区域编码' : `接口中的名称：${selectedRegionSummary.names.join(' / ') || '名称为空'}`}
                </Typography.Text>
              </div>
              <Space wrap><Tag>{selectedMembers.length} 家企业</Tag><Tag>{new Set(selectedMembers.map((item) => item.belongBuCode)).size} 个 BU</Tag>{selectedBu && <Tag color="geekblue">已限定 {selectedBu}</Tag>}</Space>
            </div>
            {selectedRegionSummary.codeNameConflict && <Alert className="section-alert" type="error" showIcon message="同一个区域编码对应多个名称" description="工具按原始数据展示，不会自动选一个名称覆盖其他名称。" />}
            <Typography.Title level={5} className="section-title">成员企业</Typography.Title>
            <OrganizationTable rows={selectedMembers} pageSize={20} />
          </>
        ) : <Empty description="请从左侧选择一个区域" />}
      </Card>
    </div>
  );
}

interface MatrixRow {
  key: string;
  code: string;
  name: string;
  total: number;
  conflict: boolean;
}

function CoverageMatrix({ analysis }: { analysis: OrganizationAnalysis }) {
  const [hideZeros, setHideZeros] = useState(false);
  const [selectedCell, setSelectedCell] = useState<{ regionCode: string; buCode: string }>();
  const matrixRows: MatrixRow[] = [
    { key: EMPTY_REGION_KEY, code: '', name: '未分配区域', total: analysis.unassignedEnterprises.length, conflict: false },
    ...analysis.regionGroups.map((region) => ({ key: region.code, code: region.code, name: region.name, total: region.enterprises.length, conflict: region.codeNameConflict })),
  ];
  const allCounts = matrixRows.flatMap((row) => analysis.buGroups.map((bu) => organizationsForCell(analysis, row.code, bu.code).length));
  const maxCount = Math.max(1, ...allCounts);

  const columns: ColumnsType<MatrixRow> = [
    {
      title: '区域',
      key: 'region',
      fixed: 'left',
      width: 210,
      render: (_, row) => <Space size={5}><strong>{row.key === EMPTY_REGION_KEY ? '未分配区域' : row.code}</strong><span>{row.key === EMPTY_REGION_KEY ? '' : row.name}</span>{row.conflict && <Tag color="red">冲突</Tag>}</Space>,
    },
    { title: '合计', dataIndex: 'total', width: 70, fixed: 'left' },
    ...analysis.buGroups.map((bu) => ({
      title: <span title={bu.name}>{bu.code}</span>,
      key: bu.code,
      width: 78,
      align: 'center' as const,
      render: (_: unknown, row: MatrixRow) => {
        const count = organizationsForCell(analysis, row.code, bu.code).length;
        if (count === 0) return hideZeros ? null : <span className="matrix-zero">—</span>;
        const strength = 0.14 + (count / maxCount) * 0.76;
        return (
          <button
            type="button"
            className="matrix-cell"
            style={{ backgroundColor: `rgba(22, 119, 255, ${strength})`, color: strength > 0.48 ? '#fff' : '#123' }}
            title={`${row.name} × ${bu.code}：${count} 家企业`}
            onClick={() => setSelectedCell({ regionCode: row.code, buCode: bu.code })}
          >{count}</button>
        );
      },
    })),
  ];
  const selectedRows = selectedCell ? organizationsForCell(analysis, selectedCell.regionCode, selectedCell.buCode) : [];
  const selectedRegionLabel = selectedCell?.regionCode
    ? `${selectedCell.regionCode} · ${analysis.regionGroups.find((item) => item.code === selectedCell.regionCode)?.name ?? ''}`
    : '未分配区域';

  return (
    <div className="coverage-view">
      <Alert type="info" showIcon message="怎么看这张图" description="上面的进度条看每个 BU 的区域覆盖率；下面的矩阵看某个区域具体落在哪个 BU。颜色越深，企业越多；点击数字可查看企业名单。" />
      <div className="bu-coverage-grid">
        {analysis.buGroups.map((bu) => (
          <Card key={bu.code} size="small">
            <div className="coverage-card-title"><strong>{bu.code}</strong><span title={bu.name}>{bu.name}</span></div>
            <Progress percent={Math.round(bu.coverageRate * 100)} status={bu.coverageRate === 1 ? 'success' : 'normal'} />
            <Typography.Text type="secondary">{bu.assignedEnterprises.length} 已分 / {bu.enterprises.length} 家企业</Typography.Text>
          </Card>
        ))}
      </div>
      <Card title={<Space><TableOutlined />BU × 区域企业数量矩阵</Space>} extra={<Space><Switch checked={hideZeros} onChange={setHideZeros} />隐藏零值</Space>}>
        <Table<MatrixRow>
          className="coverage-matrix"
          rowKey="key"
          size="small"
          bordered
          columns={columns}
          dataSource={matrixRows}
          scroll={{ x: 280 + analysis.buGroups.length * 78, y: 540 }}
          pagination={false}
        />
      </Card>
      {selectedCell && (
        <Card title={`${selectedRegionLabel} × ${selectedCell.buCode}：${selectedRows.length} 家企业`}>
          <OrganizationTable rows={selectedRows} pageSize={20} />
        </Card>
      )}
    </div>
  );
}

function ConflictRegionTable({ rows }: { rows: RegionSummary[] }) {
  return <Table<RegionSummary> rowKey="code" size="small" dataSource={rows} pagination={false} columns={[
    { title: '区域编码', dataIndex: 'code', width: 140 },
    { title: '同一编码下的名称', key: 'names', render: (_, row) => row.names.map((name) => <Tag color="red" key={name}>{name}</Tag>) },
    { title: '企业数', key: 'count', width: 90, render: (_, row) => row.enterprises.length },
    { title: 'BU', key: 'bus', width: 180, render: (_, row) => row.buCodes.join(' / ') },
  ]} />;
}

function NameConflictTable({ rows }: { rows: NameCodeConflict[] }) {
  return <Table<NameCodeConflict> rowKey="name" size="small" dataSource={rows} pagination={false} columns={[
    { title: '区域名称', dataIndex: 'name' },
    { title: '对应编码', key: 'codes', render: (_, row) => row.codes.map((code) => <Tag color="orange" key={code}>{code}</Tag>) },
    { title: '企业数', key: 'count', width: 90, render: (_, row) => row.enterprises.length },
  ]} />;
}

function DataQualityView({ analysis }: { analysis: OrganizationAnalysis }) {
  const quality = analysis.quality;
  const cards = [
    { label: '企业缺区域', value: quality.missingRegionCode.length, tone: 'warning' },
    { label: '区域编码有值但名称空', value: quality.missingRegionName.length, tone: 'danger' },
    { label: '区域编码多名称', value: quality.codeNameConflicts.length, tone: 'danger' },
    { label: '区域名称多编码', value: quality.nameCodeConflicts.length, tone: 'danger' },
    { label: '企业编码式区域码', value: quality.enterpriseCodeRegions.length, tone: 'warning' },
    { label: '企业缺 BU', value: quality.missingBu.length, tone: 'danger' },
    { label: '组织层级为空', value: analysis.unclassifiedOrganizations.length, tone: 'warning' },
    { label: '停用仍带区域', value: quality.disabledWithRegion.length, tone: 'warning' },
  ];
  return (
    <div className="quality-view">
      <Alert type="warning" showIcon message="这里只做体检，不自动修数据" description="红色或橙色表示需要主数据负责人判断；企业编码式区域码不一定错，所以只列为“需核对”。" />
      <div className="quality-card-grid">
        {cards.map((card) => <Card key={card.label} className={`quality-${card.tone}`}><Statistic title={card.label} value={card.value} /></Card>)}
      </div>
      <Card>
        <Tabs items={[
          { key: 'missing-region', label: `企业缺区域 (${quality.missingRegionCode.length})`, children: <OrganizationTable rows={quality.missingRegionCode} pageSize={20} /> },
          { key: 'missing-region-name', label: `区域缺名称 (${quality.missingRegionName.length})`, children: <OrganizationTable rows={quality.missingRegionName} /> },
          { key: 'code-name', label: `编码多名称 (${quality.codeNameConflicts.length})`, children: <ConflictRegionTable rows={quality.codeNameConflicts} /> },
          { key: 'name-code', label: `名称多编码 (${quality.nameCodeConflicts.length})`, children: <NameConflictTable rows={quality.nameCodeConflicts} /> },
          { key: 'enterprise-code', label: `企业编码式区域码 (${quality.enterpriseCodeRegions.length})`, children: <OrganizationTable rows={quality.enterpriseCodeRegions} pageSize={20} /> },
          { key: 'missing-bu', label: `企业缺 BU (${quality.missingBu.length})`, children: <OrganizationTable rows={quality.missingBu} /> },
          { key: 'unclassified', label: `层级为空 (${analysis.unclassifiedOrganizations.length})`, children: <OrganizationTable rows={analysis.unclassifiedOrganizations} pageSize={20} /> },
          { key: 'disabled-region', label: `停用仍带区域 (${quality.disabledWithRegion.length})`, children: <OrganizationTable rows={quality.disabledWithRegion} /> },
        ]} />
      </Card>
    </div>
  );
}

export default function OrganizationExplorer({ environment, refreshToken, onLoadingChange }: Props) {
  const [response, setResponse] = useState<OrganizationResponse>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [manualRefreshToken, setManualRefreshToken] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    onLoadingChange?.(true);
    setError(undefined);
    void fetchOrganizations(environment, refreshToken > 0 || manualRefreshToken > 0)
      .then((next) => active && setResponse(next))
      .catch((reason) => active && setError(reason instanceof Error ? reason.message : '组织数据加载失败'))
      .finally(() => {
        if (active) {
          setLoading(false);
          onLoadingChange?.(false);
        }
      });
    return () => { active = false; };
  }, [environment, manualRefreshToken, onLoadingChange, refreshToken]);

  const analysis = useMemo(() => analyzeOrganizations(response?.organizations ?? []), [response]);

  if (loading && !response) return <Card><Skeleton active paragraph={{ rows: 16 }} /></Card>;
  if (error) return <Alert type="error" showIcon message="组织数据没有加载成功" description={error} />;
  if (!response || analysis.stats.total === 0) return <Card><Empty description="当前环境没有组织数据" /></Card>;

  const coverageRate = analysis.stats.enterprises ? Math.round(analysis.stats.completeRegion / analysis.stats.enterprises * 100) : 0;
  return (
    <section className="organization-explorer">
      <div className="organization-source">
        <span>读取 <strong>{environment.toUpperCase()}</strong> 组织主数据 · {new Date(response.fetchedAt).toLocaleString('zh-CN')}{response.cached && ' · 本地缓存'}</span>
        <Button icon={<ReloadOutlined />} loading={loading} onClick={() => setManualRefreshToken((current) => current + 1)}>刷新组织数据</Button>
      </div>
      <section className="organization-stats-grid">
        <Card><Statistic title="全部组织" value={analysis.stats.total} prefix={<ClusterOutlined />} /></Card>
        <Card><Statistic title="集团/平台根" value={analysis.stats.platformLevel} prefix={<BankOutlined />} /></Card>
        <Card><Statistic title="二级集团 / BU" value={analysis.stats.buCount} prefix={<ApartmentOutlined />} /></Card>
        <Card><Statistic title="企业" value={analysis.stats.enterprises} prefix={<TeamOutlined />} /></Card>
        <Card><Statistic title="区域编码" value={analysis.stats.regionCount} prefix={<EnvironmentOutlined />} /></Card>
        <Card><Statistic title="已分区域企业" value={analysis.stats.completeRegion} suffix={`/ ${analysis.stats.enterprises}`} /></Card>
        <Card className="warning-card"><Statistic title="未分区域企业" value={analysis.stats.missingRegion} prefix={<WarningOutlined />} /></Card>
        <Card><Statistic title="区域覆盖率" value={coverageRate} suffix="%" /></Card>
      </section>
      <Card className="organization-tabs-card">
        <Tabs
          defaultActiveKey="organization"
          items={[
            { key: 'organization', label: <Space><ApartmentOutlined />组织树</Space>, children: <OrganizationTreeView analysis={analysis} /> },
            { key: 'region', label: <Space><EnvironmentOutlined />区域反向树</Space>, children: <RegionTreeView analysis={analysis} /> },
            { key: 'matrix', label: <Space><TableOutlined />覆盖矩阵</Space>, children: <CoverageMatrix analysis={analysis} /> },
            { key: 'quality', label: <Space><WarningOutlined />数据质量</Space>, children: <DataQualityView analysis={analysis} /> },
          ]}
        />
      </Card>
    </section>
  );
}
