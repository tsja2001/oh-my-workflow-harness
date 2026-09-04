import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ApartmentOutlined,
  BranchesOutlined,
  DatabaseOutlined,
  EnvironmentOutlined,
  NodeIndexOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import {
  Alert,
  App as AntdApp,
  Badge,
  Button,
  Card,
  Empty,
  Segmented,
  Skeleton,
  Space,
  Statistic,
  Tooltip,
} from 'antd';
import { fetchAuthStatus, fetchCategories, login } from './api';
import CategoryDetail from './components/CategoryDetail';
import CategoryTreePanel from './components/CategoryTreePanel';
import OrganizationExplorer from './components/OrganizationExplorer';
import type { CategoryForest, Environment } from './types';
import { buildCategoryForest } from './utils/tree';

const emptyForest = buildCategoryForest([]);

export default function MaterialTreeApp() {
  const { message } = AntdApp.useApp();
  const [environment, setEnvironment] = useState<Environment>('test');
  const [forest, setForest] = useState<CategoryForest>(emptyForest);
  const [otherForest, setOtherForest] = useState<CategoryForest>(emptyForest);
  const [selectedCode, setSelectedCode] = useState<string>();
  const [authStatus, setAuthStatus] = useState('正在检查登录状态…');
  const [fetchedAt, setFetchedAt] = useState<string>();
  const [cached, setCached] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [activeModule, setActiveModule] = useState<'material' | 'organization'>('material');
  const [organizationRefreshToken, setOrganizationRefreshToken] = useState(0);
  const [organizationLoading, setOrganizationLoading] = useState(false);
  const requestId = useRef(0);
  const otherEnvironment: Environment = environment === 'test' ? 'uat' : 'test';

  const loadData = useCallback(async (target: Environment, refresh = false) => {
    const id = ++requestId.current;
    setLoading(true);
    setError(undefined);
    try {
      const comparisonTarget: Environment = target === 'test' ? 'uat' : 'test';
      const [current, comparison, auth] = await Promise.all([
        fetchCategories(target, refresh),
        fetchCategories(comparisonTarget, refresh),
        fetchAuthStatus(target),
      ]);
      if (id !== requestId.current) return;
      const nextForest = buildCategoryForest(current.nodes);
      setForest(nextForest);
      setOtherForest(buildCategoryForest(comparison.nodes));
      setFetchedAt(current.fetchedAt);
      setCached(current.cached);
      setAuthStatus(auth.status);
      setSelectedCode((previous) => {
        if (previous && nextForest.byCode.has(previous)) return previous;
        if (nextForest.byCode.has('15010112')) return '15010112';
        return nextForest.roots[0]?.classCode;
      });
    } catch (reason) {
      if (id !== requestId.current) return;
      setError(reason instanceof Error ? reason.message : '加载失败');
    } finally {
      if (id === requestId.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData(environment);
  }, [environment, loadData]);

  const selected = useMemo(
    () => selectedCode ? forest.byCode.get(selectedCode) : undefined,
    [forest, selectedCode],
  );

  const forceLogin = async () => {
    try {
      setAuthStatus('正在重新登录…');
      const result = await login(environment);
      const status = await fetchAuthStatus(environment);
      setAuthStatus(status.status);
      message.success(result.status);
      await loadData(environment, true);
    } catch (reason) {
      const text = reason instanceof Error ? reason.message : '重新登录失败';
      setAuthStatus(text);
      message.error(text);
    }
  };

  const refreshCurrentModule = () => {
    if (activeModule === 'material') {
      void loadData(environment, true);
      return;
    }
    setOrganizationRefreshToken((current) => current + 1);
  };

  const handleOrganizationLoading = useCallback((nextLoading: boolean) => {
    setOrganizationLoading(nextLoading);
  }, []);

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand">
          <div className="brand-mark"><ApartmentOutlined /></div>
          <div>
            <h1>招采主数据全景</h1>
            <p>物料类目 · 组织层级 · 区域覆盖 · test/UAT</p>
          </div>
        </div>
        <div className="topbar-actions">
          <Segmented<Environment>
            value={environment}
            options={[
              { label: 'TEST', value: 'test' },
              { label: 'UAT', value: 'uat' },
            ]}
            onChange={setEnvironment}
          />
          <Tooltip title={authStatus}>
            <Badge status={error ? 'error' : loading ? 'processing' : 'success'} text="自动登录" />
          </Tooltip>
          <Button icon={<SafetyCertificateOutlined />} onClick={() => void forceLogin()}>
            重新登录
          </Button>
          <Button
            type="primary"
            icon={<ReloadOutlined spin={activeModule === 'material' ? loading : organizationLoading} />}
            onClick={refreshCurrentModule}
          >
            刷新数据
          </Button>
        </div>
      </header>

      <main className="workspace">
        <div className="context-strip">
          <div>
            当前读取 <strong>{environment.toUpperCase()}</strong> 招采 MDM 主数据
            {fetchedAt && <span> · {new Date(fetchedAt).toLocaleString('zh-CN')}</span>}
            {cached && <span> · 本地缓存</span>}
          </div>
          <div className="auth-summary">{authStatus}</div>
        </div>

        <div className="module-switch">
          <Segmented<'material' | 'organization'>
            block
            value={activeModule}
            options={[
              { value: 'material', label: <Space><NodeIndexOutlined />物料类目与具体物料</Space> },
              { value: 'organization', label: <Space><EnvironmentOutlined />集团、BU、企业与区域</Space> },
            ]}
            onChange={setActiveModule}
          />
        </div>

        {activeModule === 'material' && error && (
          <Alert
            type="error"
            showIcon
            message="数据没有加载成功"
            description={error}
            action={<Button onClick={() => void loadData(environment, true)}>重试</Button>}
          />
        )}

        {activeModule === 'material' && <section className="stats-grid">
          <Card><Statistic title="类目总数" value={forest.stats.total} prefix={<DatabaseOutlined />} /></Card>
          <Card><Statistic title="末级类目" value={forest.stats.leaf} prefix={<BranchesOutlined />} /></Card>
          {[1, 2, 3, 4].map((level) => (
            <Card key={level}>
              <Statistic title={`${level} 级类目`} value={forest.stats.levels[level] ?? 0} />
            </Card>
          ))}
          <Card className={forest.stats.orphan ? 'warning-card' : ''}>
            <Statistic title="断链节点" value={forest.stats.orphan} prefix={<WarningOutlined />} />
          </Card>
          <Card><Statistic title="停用节点" value={forest.stats.disabled} /></Card>
        </section>}

        {activeModule === 'organization' ? (
          <OrganizationExplorer
            environment={environment}
            refreshToken={organizationRefreshToken}
            onLoadingChange={handleOrganizationLoading}
          />
        ) : loading && forest.stats.total === 0 ? (
          <Card><Skeleton active paragraph={{ rows: 12 }} /></Card>
        ) : forest.stats.total === 0 && !error ? (
          <Card><Empty description="当前环境没有类目数据" /></Card>
        ) : (
          <section className="main-grid">
            <CategoryTreePanel
              forest={forest}
              selectedCode={selectedCode}
              onSelect={setSelectedCode}
            />
            <CategoryDetail
              key={`${environment}-${selectedCode ?? 'none'}`}
              environment={environment}
              otherEnvironment={otherEnvironment}
              forest={forest}
              otherForest={otherForest}
              selected={selected}
            />
          </section>
        )}

        <footer className="footer-note">
          <Space split="·">
            <span>只读工具</span>
            <span>仅监听 127.0.0.1</span>
            <span>登录由工作区脚本托管</span>
            <span>不支持生产环境</span>
          </Space>
        </footer>
      </main>
    </div>
  );
}
