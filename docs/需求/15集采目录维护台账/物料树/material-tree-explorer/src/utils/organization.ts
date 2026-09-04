import type {
  BuSummary,
  NameCodeConflict,
  OrganizationAnalysis,
  OrganizationRecord,
  RegionSummary,
} from '../types';

export const cleanText = (value: string | null | undefined) => String(value ?? '').trim();

function compareCode(left: string, right: string) {
  return left.localeCompare(right, 'zh-CN', { numeric: true });
}

function uniqueTexts(values: string[]) {
  return [...new Set(values.map(cleanText).filter(Boolean))].sort((left, right) => left.localeCompare(right, 'zh-CN'));
}

function mostFrequentText(values: string[], fallback: string) {
  const counts = new Map<string, number>();
  for (const value of values.map(cleanText).filter(Boolean)) {
    counts.set(value, (counts.get(value) ?? 0) + 1);
  }
  return [...counts.entries()].sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0], 'zh-CN'))[0]?.[0] ?? fallback;
}

function hasRegionCode(organization: OrganizationRecord) {
  return Boolean(cleanText(organization.belongPlateCode));
}

function hasCompleteRegion(organization: OrganizationRecord) {
  return hasRegionCode(organization) && Boolean(cleanText(organization.belongPlateName));
}

export function analyzeOrganizations(organizations: OrganizationRecord[]): OrganizationAnalysis {
  const groupRoots = organizations.filter((item) => item.organizationLevel === 'JT');
  const enterprises = organizations.filter((item) => item.organizationLevel === 'BS');
  const unclassifiedOrganizations = organizations.filter((item) => !cleanText(item.organizationLevel));
  const buCodes = uniqueTexts(organizations.map((item) => item.belongBuCode));

  const buGroups: BuSummary[] = buCodes.map((code) => {
    const members = organizations.filter((item) => cleanText(item.belongBuCode) === code);
    const buEnterprises = enterprises.filter((item) => cleanText(item.belongBuCode) === code);
    const assignedEnterprises = buEnterprises.filter(hasCompleteRegion);
    const names = uniqueTexts(members.map((item) => item.belongBuName));
    return {
      code,
      name: mostFrequentText(members.map((item) => item.belongBuName), code),
      names,
      anchorOrganizations: members.filter((item) => item.organizationLevel === 'GS' || item.organizationLevel === 'JT'),
      enterprises: [...buEnterprises].sort((left, right) => compareCode(left.orgCode, right.orgCode)),
      assignedEnterprises,
      coverageRate: buEnterprises.length ? assignedEnterprises.length / buEnterprises.length : 0,
    };
  }).sort((left, right) => compareCode(left.code, right.code));

  const assignedByCode = new Map<string, OrganizationRecord[]>();
  for (const enterprise of enterprises.filter(hasRegionCode)) {
    const code = cleanText(enterprise.belongPlateCode);
    const members = assignedByCode.get(code) ?? [];
    members.push(enterprise);
    assignedByCode.set(code, members);
  }

  const regionGroups: RegionSummary[] = [...assignedByCode.entries()].map(([code, members]) => {
    const names = uniqueTexts(members.map((item) => item.belongPlateName));
    return {
      code,
      name: mostFrequentText(members.map((item) => item.belongPlateName), '区域名称为空'),
      names,
      enterprises: [...members].sort((left, right) => compareCode(left.orgCode, right.orgCode)),
      buCodes: uniqueTexts(members.map((item) => item.belongBuCode)),
      codeNameConflict: names.length > 1,
      enterpriseCodeMatches: members.filter((item) => cleanText(item.orgCode) === code),
    };
  }).sort((left, right) => right.enterprises.length - left.enterprises.length || compareCode(left.code, right.code));

  const regionsByName = new Map<string, OrganizationRecord[]>();
  for (const enterprise of enterprises.filter(hasRegionCode)) {
    const name = cleanText(enterprise.belongPlateName);
    if (!name) continue;
    const members = regionsByName.get(name) ?? [];
    members.push(enterprise);
    regionsByName.set(name, members);
  }
  const nameCodeConflicts: NameCodeConflict[] = [...regionsByName.entries()]
    .map(([name, members]) => ({
      name,
      codes: uniqueTexts(members.map((item) => item.belongPlateCode)),
      enterprises: members,
    }))
    .filter((item) => item.codes.length > 1)
    .sort((left, right) => left.name.localeCompare(right.name, 'zh-CN'));

  const unassignedEnterprises = enterprises.filter((item) => !hasRegionCode(item));
  const completeRegion = enterprises.filter(hasCompleteRegion).length;
  const groupName = groupRoots.find((item) => item.state === '1')?.shortName
    || groupRoots.find((item) => item.state === '1')?.orgName
    || groupRoots[0]?.shortName
    || groupRoots[0]?.orgName
    || '集团根节点';

  return {
    groupName: cleanText(groupName),
    groupRoots,
    enterprises,
    buGroups,
    regionGroups,
    unassignedEnterprises,
    unclassifiedOrganizations,
    quality: {
      missingRegionCode: unassignedEnterprises,
      missingRegionName: enterprises.filter((item) => hasRegionCode(item) && !cleanText(item.belongPlateName)),
      missingBu: enterprises.filter((item) => !cleanText(item.belongBuCode)),
      codeNameConflicts: regionGroups.filter((item) => item.codeNameConflict),
      nameCodeConflicts,
      enterpriseCodeRegions: enterprises.filter((item) => cleanText(item.belongPlateCode) === cleanText(item.orgCode) && hasRegionCode(item)),
      disabledWithRegion: organizations.filter((item) => item.state !== '1' && hasRegionCode(item)),
    },
    stats: {
      total: organizations.length,
      enterprises: enterprises.length,
      groupLevel: organizations.filter((item) => item.organizationLevel === 'GS').length,
      platformLevel: groupRoots.length,
      unclassified: unclassifiedOrganizations.length,
      buCount: buGroups.length,
      regionCount: regionGroups.length,
      assignedRegion: enterprises.length - unassignedEnterprises.length,
      completeRegion,
      missingRegion: unassignedEnterprises.length,
    },
  };
}

export function organizationsForCell(
  analysis: OrganizationAnalysis,
  regionCode: string,
  buCode: string,
) {
  const source = regionCode
    ? analysis.regionGroups.find((item) => item.code === regionCode)?.enterprises ?? []
    : analysis.unassignedEnterprises;
  return source.filter((item) => cleanText(item.belongBuCode) === buCode);
}

export function organizationMatches(organization: OrganizationRecord, keyword: string) {
  const normalized = cleanText(keyword).toLocaleLowerCase();
  if (!normalized) return true;
  return [
    organization.orgCode,
    organization.orgName,
    organization.shortName,
    organization.belongBuCode,
    organization.belongBuName,
    organization.belongPlateCode,
    organization.belongPlateName,
  ].some((value) => cleanText(value).toLocaleLowerCase().includes(normalized));
}
