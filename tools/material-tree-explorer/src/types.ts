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
