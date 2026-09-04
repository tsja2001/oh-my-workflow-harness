import type {
  CategoryResponse,
  Environment,
  MaterialFilters,
  MaterialResponse,
  OrganizationResponse,
} from './types';

async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error || `请求失败（HTTP ${response.status}）`);
  }
  return payload as T;
}

export function fetchCategories(environment: Environment, refresh = false) {
  const search = new URLSearchParams({ environment });
  if (refresh) search.set('refresh', '1');
  return requestJson<CategoryResponse>(`/api/categories?${search}`);
}

export function fetchOrganizations(environment: Environment, refresh = false) {
  const search = new URLSearchParams({ environment });
  if (refresh) search.set('refresh', '1');
  return requestJson<OrganizationResponse>(`/api/organizations?${search}`);
}

export function fetchAuthStatus(environment: Environment) {
  return requestJson<{ environment: Environment; status: string }>(
    `/api/auth/status?environment=${environment}`,
  );
}

export function login(environment: Environment) {
  return requestJson<{ environment: Environment; status: string }>('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ environment }),
  });
}

export function fetchMaterials(
  environment: Environment,
  filters: MaterialFilters,
  currentPage: number,
  limit: number,
) {
  return requestJson<MaterialResponse>('/api/materials', {
    method: 'POST',
    body: JSON.stringify({ environment, ...filters, currentPage, limit }),
  });
}
