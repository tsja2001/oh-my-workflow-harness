import React from 'react';
import ReactDOM from 'react-dom/client';
import { App as AntdApp, ConfigProvider } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import MaterialTreeApp from './App';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: '#0b6bcb',
          borderRadius: 10,
          colorBgLayout: '#edf3f8',
          fontFamily: 'Inter, "PingFang SC", "Microsoft YaHei", sans-serif',
        },
        components: {
          Card: { headerBg: '#fbfdff' },
          Tree: { nodeHoverBg: '#eaf3ff', nodeSelectedBg: '#dcecff' },
        },
      }}
    >
      <AntdApp>
        <MaterialTreeApp />
      </AntdApp>
    </ConfigProvider>
  </React.StrictMode>,
);
