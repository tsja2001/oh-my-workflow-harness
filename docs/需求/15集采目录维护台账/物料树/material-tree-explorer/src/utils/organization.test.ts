import { describe, expect, it } from 'vitest';
import type { OrganizationRecord } from '../types';
import { analyzeOrganizations, organizationsForCell } from './organization';

const organization = (overrides: Partial<OrganizationRecord>): OrganizationRecord => ({
  orgId: '',
  orgCode: '',
  orgName: '',
  shortName: '',
  shortFullName: '',
  state: '1',
  stateDesc: '启用',
  organizationLevel: 'BS',
  authLevel: 'BS',
  orgType: 'C',
  orgTypeDesc: '公司',
  businessType: '',
  businessTypeDesc: '',
  belongBuCode: 'BU001',
  belongBuName: '第一板块',
  belongPlateCode: '',
  belongPlateName: '',
  belongCompanyOrgCode: '',
  belongCompanyOrgName: '',
  areaPurchase: null,
  areaPurchaseDesc: '',
  isOffice: '',
  belongOfficeCode: '',
  belongOfficeName: '',
  companyAddress: '',
  updateTime: null,
  ...overrides,
});

const records = [
  organization({ orgCode: 'G1', orgName: '示例集团', shortName: '集团', organizationLevel: 'JT' }),
  organization({ orgCode: 'B1', orgName: '第一板块公司', organizationLevel: 'GS' }),
  organization({ orgCode: 'E1', orgName: '企业一', belongPlateCode: 'R1', belongPlateName: '北区' }),
  organization({ orgCode: 'E2', orgName: '企业二', belongPlateCode: 'R1', belongPlateName: '北部区域' }),
  organization({ orgCode: 'E3', orgName: '企业三', belongBuCode: 'BU002', belongBuName: '第二板块', belongPlateCode: 'R2', belongPlateName: '北区' }),
  organization({ orgCode: 'E4', orgName: '企业四', belongBuCode: 'BU002', belongBuName: '第二板块' }),
  organization({ orgCode: 'X1', orgName: '未分级', organizationLevel: '' }),
];

describe('组织与区域分析', () => {
  it('按集团、BU、企业分层并计算区域覆盖率', () => {
    const analysis = analyzeOrganizations(records);
    expect(analysis.groupName).toBe('集团');
    expect(analysis.stats.enterprises).toBe(4);
    expect(analysis.stats.buCount).toBe(2);
    expect(analysis.stats.assignedRegion).toBe(3);
    expect(analysis.stats.missingRegion).toBe(1);
    expect(analysis.buGroups.find((item) => item.code === 'BU002')?.coverageRate).toBe(0.5);
  });

  it('识别区域编码和名称的双向冲突', () => {
    const analysis = analyzeOrganizations(records);
    expect(analysis.quality.codeNameConflicts.map((item) => item.code)).toEqual(['R1']);
    expect(analysis.quality.nameCodeConflicts[0]).toMatchObject({ name: '北区', codes: ['R1', 'R2'] });
  });

  it('矩阵单元格能反查具体企业', () => {
    const analysis = analyzeOrganizations(records);
    expect(organizationsForCell(analysis, 'R1', 'BU001').map((item) => item.orgCode)).toEqual(['E1', 'E2']);
    expect(organizationsForCell(analysis, '', 'BU002').map((item) => item.orgCode)).toEqual(['E4']);
  });
});
