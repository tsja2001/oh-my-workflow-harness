import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;

import java.util.*;

/**
 * 复现 IFS 生产错误：JSON.toJSON(嵌套Bean) 在 fastjson 2.0.62 下，
 * 嵌套 Bean 不再变成 JSONObject，导致 QLExpress 的 detailObj.get("content") 找不到 get(String)。
 * 并验证三种修法。全程用公司实际依赖 com.alibaba.fastjson:2.0.62（1.x 兼容 API）。
 */
public class IfsToJsonExp {

    // 模拟 ProductSkuCache（@Data：只有 getContent()，没有 get(String)）
    public static class Cache {
        private String content;
        private Date createTime;
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
        public Date getCreateTime() { return createTime; }
        public void setCreateTime(Date createTime) { this.createTime = createTime; }
    }
    // 模拟 ProductSkuModel（含 Map<String, Cache> detailMap）
    public static class Model {
        private String skuId;
        private Date bizTime;                       // 顶层日期字段，检验是否被转坏
        private Map<String, Cache> detailMap;
        public String getSkuId() { return skuId; }
        public void setSkuId(String s) { this.skuId = s; }
        public Date getBizTime() { return bizTime; }
        public void setBizTime(Date d) { this.bizTime = d; }
        public Map<String, Cache> getDetailMap() { return detailMap; }
        public void setDetailMap(Map<String, Cache> m) { this.detailMap = m; }
    }

    static int pass = 0, fail = 0;
    static void check(String name, boolean ok) {
        System.out.println((ok ? "  [PASS] " : "  [FAIL] ") + name);
        if (ok) { pass++; } else { fail++; }
    }

    // QLExpress 的 detailObj.get("content") 只有当对象是 Map 才有 get(String)。
    static boolean getStringWorks(Object o) { return o instanceof Map; }

    public static void main(String[] args) {
        Model model = new Model();
        model.setSkuId("SKU-001");
        model.setBizTime(new Date());
        Cache c = new Cache();
        c.setContent("hello-content");
        c.setCreateTime(new Date());
        Map<String, Cache> dm = new HashMap<String, Cache>();
        dm.put("detail", c);
        model.setDetailMap(dm);

        System.out.println("fastjson version = " + JSON.VERSION);

        // ---------- 现状：直接 JSON.toJSON（生产代码 AIMStepEngine:93 的写法）----------
        System.out.println("\n== A. 现状 JSON.toJSON(model)（复现线上错误）==");
        Object j = JSON.toJSON(model);
        Object detailMap = ((Map) j).get("detailMap");
        Object detailObj = ((Map) detailMap).get("detail");
        System.out.println("  outer     = " + j.getClass().getName());
        System.out.println("  detailMap = " + detailMap.getClass().getName());
        System.out.println("  detailObj = " + detailObj.getClass().getName());
        check("detailMap.get(\"detail\") 能拿到（Map）", getStringWorks(detailMap));
        check("detailObj 是 Map（即 get(\"content\") 可用）", getStringWorks(detailObj));
        System.out.println("  => 上面这条若 FAIL，就是生产 'get(String) 找不到' 的根因");

        // ---------- 修法1：文本往返 JSON.parse(JSON.toJSONString) ----------
        System.out.println("\n== B. 修法1：JSON.parse(JSON.toJSONString(model)) ==");
        Object b = JSON.parse(JSON.toJSONString(model));
        Object bDetailObj = ((Map) ((Map) b).get("detailMap")).get("detail");
        Object bBizTime = ((Map) b).get("bizTime");
        check("嵌套对象变成 Map（get(\"content\") 可用）", getStringWorks(bDetailObj));
        check("顶层日期仍是 Date（不被转成字符串）", bBizTime instanceof Date);
        System.out.println("  bizTime 实际类型 = " + bBizTime.getClass().getName());
        System.out.println("  => 若日期这条 FAIL，就是 codex 担心的“重演日期变字符串”风险");

        // ---------- 修法2：递归规范化（不走文本，保真标量）----------
        System.out.println("\n== C. 修法2：递归规范化 normalize()（推荐）==");
        Object n = normalize(model);
        Object nDetailObj = ((Map) ((Map) n).get("detailMap")).get("detail");
        Object nBizTime = ((Map) n).get("bizTime");
        Object nContent = ((Map) nDetailObj).get("content");
        Object nCacheTime = ((Map) nDetailObj).get("createTime");
        check("嵌套对象变成 Map（get(\"content\") 可用）", getStringWorks(nDetailObj));
        check("能取到 content 值：" + nContent, "hello-content".equals(nContent));
        check("顶层日期仍是 Date", nBizTime instanceof Date);
        check("嵌套对象里的日期也仍是 Date", nCacheTime instanceof Date);
        System.out.println("  bizTime=" + nBizTime.getClass().getSimpleName()
                + ", cache.createTime=" + nCacheTime.getClass().getSimpleName());

        System.out.println("\n结果：通过 " + pass + " / 失败 " + fail);
    }

    // 递归把 Bean/Map/List 变成 JSONObject/JSONArray，标量（Date/数字/布尔/字符串/枚举/java.time）原样保留
    static Object normalize(Object o) {
        if (o == null) return null;
        if (o instanceof Map) {
            JSONObject r = new JSONObject();
            for (Object e : ((Map<?, ?>) o).entrySet()) {
                Map.Entry<?, ?> en = (Map.Entry<?, ?>) e;
                r.put(String.valueOf(en.getKey()), normalize(en.getValue()));
            }
            return r;
        }
        if (o instanceof Collection) {
            JSONArray r = new JSONArray();
            for (Object e : (Collection<?>) o) r.add(normalize(e));
            return r;
        }
        if (o instanceof Object[]) {
            JSONArray r = new JSONArray();
            for (Object e : (Object[]) o) r.add(normalize(e));
            return r;
        }
        Class<?> cls = o.getClass();
        if (o instanceof CharSequence || o instanceof Number || o instanceof Boolean
                || o instanceof Date || o instanceof Character || cls.isEnum()
                || cls.isPrimitive() || cls.getName().startsWith("java.time.")) {
            return o;
        }
        // 其余视为 Bean：先用 toJSON 转一层，再递归
        Object j = JSON.toJSON(o);
        if (j instanceof Map || j instanceof Collection || j instanceof Object[]) {
            return normalize(j);
        }
        return j;
    }
}
