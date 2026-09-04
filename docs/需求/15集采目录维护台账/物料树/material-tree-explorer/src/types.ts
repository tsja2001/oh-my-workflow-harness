export type Environment = 'test' | 'uat';

export interface CategoryRecord {
  classId: string;
  classCode: string;
  className: string;
  parentClassCode: string;
  parentClassName: string;
  state: string;
  upperTime: string | null;
  updateTime: string | null;
  unit: string;
  unitCode: string;
  purchaseType: string;
  purchaseTypeDesc: string;
  description: string;
  dataSource: string;
}

export interface CategoryNode extends CategoryRecord {
  children: CategoryNode[];
  level: number;
  isLeaf: boolean;
  pathCodes: string[];
  pathNames: string[];
  descendantCount: number;
  orphan: boolean;
}

export interface CategoryStats {
  total: number;
  enabled: number;
  disabled: number;
  leaf: number;
  orphan: number;
  duplicateCodes: number;
  levels: Record<number, number>;
}

export interface CategoryForest {
  roots: CategoryNode[];
  nodes: CategoryNode[];
  byCode: Map<string, CategoryNode>;
  stats: CategoryStats;
}

export interface CategoryResponse {
  environment: Environment;
  fetchedAt: string;
  totalCount: number;
  nodes: CategoryRecord[];
  cached: boolean;
  notice: string;
  source: {
    endpoint: string;
    authentication: string;
  };
}

export interface CategoryFilters {
  keyword: string;
  level: number | 'all';
  state: 'all' | '1' | '0';
  leafOnly: boolean;
}

export interface MaterialFilters {
  searchWord?: string;
  productCode?: string;
  productName?: string;
  productDesc?: string;
  productShortDesc?: string;
  categoryCode?: string;
}

export interface MaterialRecord {
  productId: string;
  productCode: string;
  productName: string;
  productDesc: string;
  productShortDesc: string | null;
  categoryCode: string;
  categoryName: string;
  categoryPathCode: string;
  categoryPathName: string;
  unit: string;
  purchaseTypeDesc: string | null;
  updateTime: string | null;
  state: string;
}

export interface MaterialResponse {
  environment: Environment;
  currentPage: number;
  limit: number;
  totalCount: number;
  totalPage: number;
  rows: MaterialRecord[];
  fetchedAt: string;
  notice: string;
}

export interface CategoryDifference {
  onlyCurrent: CategoryNode[];
  onlyOther: CategoryNode[];
  nameChanges: Array<{ current: CategoryNode; other: CategoryNode }>;
  stateChanges: Array<{ current: CategoryNode; other: CategoryNode }>;
}

export interface OrganizationRecord {
  orgId: string;
  orgCode: string;
  orgName: string;
  shortName: string;
  shortFullName: string;
  state: string;
  stateDesc: string;
  organizationLevel: string;
  authLevel: string;
  orgType: string;
  orgTypeDesc: string;
  businessType: string;
  businessTypeDesc: string;
  belongBuCode: string;
  belongBuName: string;
  belongPlateCode: string;
  belongPlateName: string;
  belongCompanyOrgCode: string;
  belongCompanyOrgName: string;
  areaPurchase: number | null;
  areaPurchaseDesc: string;
  isOffice: string;
  belongOfficeCode: string;
  belongOfficeName: string;
  companyAddress: string;
  updateTime: string | null;
}

export interface OrganizationResponse {
  environment: Environment;
  fetchedAt: string;
  totalCount: number;
  organizations: OrganizationRecord[];
  cached: boolean;
  notice: string;
  source: {
    endpoint: string;
    authentication: string;
  };
}

export interface BuSummary {
  code: string;
  name: string;
  names: string[];
  anchorOrganizations: OrganizationRecord[];
  enterprises: OrganizationRecord[];
  assignedEnterprises: OrganizationRecord[];
  coverageRate: number;
}

export interface RegionSummary {
  code: string;
  name: string;
  names: string[];
  enterprises: OrganizationRecord[];
  buCodes: string[];
  codeNameConflict: boolean;
  enterpriseCodeMatches: OrganizationRecord[];
}

export interface NameCodeConflict {
  name: string;
  codes: string[];
  enterprises: OrganizationRecord[];
}

export interface OrganizationAnalysis {
  groupName: string;
  groupRoots: OrganizationRecord[];
  enterprises: OrganizationRecord[];
  buGroups: BuSummary[];
  regionGroups: RegionSummary[];
  unassignedEnterprises: OrganizationRecord[];
  unclassifiedOrganizations: OrganizationRecord[];
  quality: {
    missingRegionCode: OrganizationRecord[];
    missingRegionName: OrganizationRecord[];
    missingBu: OrganizationRecord[];
    codeNameConflicts: RegionSummary[];
    nameCodeConflicts: NameCodeConflict[];
    enterpriseCodeRegions: OrganizationRecord[];
    disabledWithRegion: OrganizationRecord[];
  };
  stats: {
    total: number;
    enterprises: number;
    groupLevel: number;
    platformLevel: number;
    unclassified: number;
    buCount: number;
    regionCount: number;
    assignedRegion: number;
    completeRegion: number;
    missingRegion: number;
  };
}
