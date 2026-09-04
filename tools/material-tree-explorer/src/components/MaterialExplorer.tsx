import { useEffect, useState } from 'react';
import { CopyOutlined, DownloadOutlined, SearchOutlined } from '@ant-design/icons';
import {
  Alert,
  App as AntdApp,
  Button,
  Form,
  Input,
  Pagination,
  Space,
  Table,
  Tag,
  Typography,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { fetchMaterials } from '../api';
import type {
  CategoryNode,
  Environment,
  MaterialFilters,
  MaterialRecord,
  MaterialResponse,
} from '../types';
import { downloadCsv } from '../utils/export';

interface Props {
  environment: Environment;
  selected?: CategoryNode;
}

export default function MaterialExplorer({ environment, selected }: Props) {
  const { message } = AntdApp.useApp();
  const [form] = Form.useForm<MaterialFilters>();
  const [result, setResult] = useState<MaterialResponse>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>();

  const runQuery = async (currentPage = 1, limit = result?.limit ?? 20, override?: MaterialFilters) => {
    setLoading(true);
    setError(undefined);
    try {
      const values = override ?? form.getFieldsValue();
      const response = await fetchMaterials(environment, values, currentPage, limit);
      setResult(response);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : '物料查询失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const categoryCode = selected?.classCode;
    form.setFieldsValue({ categoryCode });
    setResult(undefined);
    setError(undefined);
    if (categoryCode) void runQuery(1, 20, { categoryCode });
    // 选择节点或切环境时，以当前节点作为新的查询起点。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [environment, selected?.classCode]);

  const copy = async (text: string) => {
    await navigator.clipboard.writeText(text);
    message.success('已复制');
  };

  const columns: ColumnsType<MaterialRecord> = [
    {
      title: '物料组',
      width: 190,
      fixed: 'left',
      render: (_, row) => <><Typography.Text code>{row.categoryCode}</Typography.Text><br />{row.categoryName}</>,
    },
    {
      title: '物料编码',
      dataIndex: 'productCode',
      width: 170,
      fixed: 'left',
      render: (value: string) => (
        <Space size={4}><Typography.Text copyable={false}>{value}</Typography.Text><Button type="text" size="small" icon={<CopyOutlined />} onClick={() => void copy(value)} /></Space>
      ),
    },
    { title: '物料名称', dataIndex: 'productName', width: 140 },
    { title: '物料描述', dataIndex: 'productDesc', width: 260, ellipsis: true },
    {
      title: '完整类目路径',
      dataIndex: 'categoryPathName',
      width: 320,
      render: (value: string, row) => (
        <Space direction="vertical" size={0}>
          <Typography.Text>{value || '-'}</Typography.Text>
          <Typography.Text type="secondary" className="small-text">{row.categoryPathCode || '-'}</Typography.Text>
        </Space>
      ),
    },
    { title: '单位', dataIndex: 'unit', width: 90, render: (value: string) => value || '-' },
    { title: '采购组织方式', dataIndex: 'purchaseTypeDesc', width: 130, render: (value) => value || '-' },
    {
      title: '状态',
      dataIndex: 'state',
      width: 90,
      render: (value: string) => <Tag color={value === '1' ? 'green' : 'default'}>{value === '1' ? '启用' : value}</Tag>,
    },
    { title: '更新时间', dataIndex: 'updateTime', width: 190, render: (value: string | null) => value ? new Date(value).toLocaleString('zh-CN') : '-' },
  ];

  const exportCurrentPage = () => {
    if (!result?.rows.length) return;
    downloadCsv(
      `${environment}-物料查询-第${result.currentPage}页.csv`,
      ['类目编码', '类目名称', '物料编码', '物料名称', '物料描述', '类目路径编码', '类目路径名称', '单位', '采购组织方式', '更新时间'],
      result.rows.map((row) => [
        row.categoryCode,
        row.categoryName,
        row.productCode,
        row.productName,
        row.productDesc,
        row.categoryPathCode,
        row.categoryPathName,
        row.unit,
        row.purchaseTypeDesc,
        row.updateTime,
      ]),
    );
  };

  return (
    <div className="material-explorer">
      <Alert
        type="info"
        showIcon
        message="这里查询的是启用中的 MDM 物料"
        description="选一级、二级、三级或四级类目都会包含它下面的物料；没有选择类目时可全库搜索。"
      />
      <Form<MaterialFilters> form={form} layout="vertical" onFinish={() => void runQuery(1)}>
        <div className="material-form-grid">
          <Form.Item label="综合关键词" name="searchWord"><Input allowClear placeholder="编码 / 类目 / 物料描述" /></Form.Item>
          <Form.Item label="类目编码" name="categoryCode"><Input allowClear placeholder="2 / 4 / 6 / 8 位" /></Form.Item>
          <Form.Item label="物料编码" name="productCode"><Input allowClear placeholder="支持包含查询" /></Form.Item>
          <Form.Item label="物料名称" name="productName"><Input allowClear placeholder="支持包含查询" /></Form.Item>
          <Form.Item label="物料长描述" name="productDesc"><Input allowClear /></Form.Item>
          <Form.Item label="物料短描述" name="productShortDesc"><Input allowClear /></Form.Item>
        </div>
        <Space wrap>
          <Button type="primary" htmlType="submit" icon={<SearchOutlined />} loading={loading}>查询</Button>
          <Button onClick={() => { form.resetFields(); setResult(undefined); setError(undefined); }}>清空全部</Button>
          <Button onClick={() => form.setFieldValue('categoryCode', undefined)}>清空类目限制</Button>
          <Button icon={<DownloadOutlined />} disabled={!result?.rows.length} onClick={exportCurrentPage}>导出当前页 CSV</Button>
        </Space>
      </Form>

      {error && <Alert className="section-alert" type="error" showIcon message={error} />}

      <div className="table-summary">
        <Typography.Text strong>{result ? `共 ${result.totalCount.toLocaleString()} 条` : '设置条件后查询'}</Typography.Text>
        {result && <Typography.Text type="secondary">本页 {result.rows.length} 条 · {new Date(result.fetchedAt).toLocaleString('zh-CN')}</Typography.Text>}
      </div>
      <Table<MaterialRecord>
        rowKey={(row) => row.productId || row.productCode}
        columns={columns}
        dataSource={result?.rows ?? []}
        loading={loading}
        pagination={false}
        size="small"
        scroll={{ x: 1580, y: 410 }}
      />
      {result && result.totalCount > 0 && (
        <Pagination
          className="material-pagination"
          current={result.currentPage}
          pageSize={result.limit}
          total={result.totalCount}
          showSizeChanger
          showQuickJumper
          pageSizeOptions={[10, 20, 50, 100]}
          showTotal={(total) => `共 ${total.toLocaleString()} 条`}
          onChange={(page, size) => void runQuery(page, size)}
        />
      )}
    </div>
  );
}
