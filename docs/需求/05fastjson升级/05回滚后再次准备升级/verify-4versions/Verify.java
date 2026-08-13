import com.alibaba.fastjson.*;
import com.pcitc.scm.share.rule.utils.JsonUtils;
import com.pcitc.scm.common.json.JsonTransferUtil;
import java.util.*;

/** 直接调用本次改动后编译出来的真实类，验证三项行为 */
public class Verify {
    static int pass=0, fail=0;
    static void ck(String name, boolean ok, String detail){
        System.out.println((ok?"  ✅ ":"  ❌ ")+name+"  ["+detail+"]");
        if(ok) pass++; else fail++;
    }
    static String cn(Object o){ return o==null?"null":o.getClass().getSimpleName(); }

    public static class Cache { private String content="C"; private Date bizTime=new Date(1780000000000L);
        public String getContent(){return content;} public Date getBizTime(){return bizTime;} }
    public static class SkuModel {
        private Map<String,Cache> detailMap = new HashMap<>();
        private List<Cache> list = new ArrayList<>();
        private Cache[] arr;
        private Cache direct = new Cache();
        private Date topTime = new Date(1780000000000L);
        public SkuModel(){ detailMap.put("detail", new Cache()); list.add(new Cache()); arr=new Cache[]{new Cache()}; }
        public Map<String,Cache> getDetailMap(){return detailMap;}
        public List<Cache> getList(){return list;}
        public Cache[] getArr(){return arr;}
        public Cache getDirect(){return direct;}
        public Date getTopTime(){return topTime;}
    }

    public static void main(String[] a){
        System.out.println("fastjson jar = "+JSON.class.getProtectionDomain().getCodeSource().getLocation());
        System.out.println();

        // ===================== B3：规则上下文规范化 =====================
        System.out.println("===== B3  JsonUtils.toRuleContextValue（规则脚本能不能 .get） =====");
        Object norm = JsonUtils.toRuleContextValue(new SkuModel());
        ck("顶层是 Map", norm instanceof Map, cn(norm));
        Map<?,?> m = (Map<?,?>) norm;

        Object dm = m.get("detailMap");
        ck("detailMap 是 Map", dm instanceof Map, cn(dm));
        Object detail = ((Map<?,?>)dm).get("detail");
        ck("detailMap.detail 是 Map（线上报错那一处）", detail instanceof Map, cn(detail));
        if(detail instanceof Map){
            Object c = ((Map<?,?>)detail).get("content");
            ck("  能取到 content", "C".equals(c), String.valueOf(c));
            Object bt = ((Map<?,?>)detail).get("bizTime");
            ck("  嵌套日期仍是 Date（不能变时间戳/字符串）", bt instanceof Date, cn(bt)+"="+bt);
        }
        Object lst = m.get("list");
        ck("list 是 List", lst instanceof List, cn(lst));
        ck("list[0] 是 Map", ((List<?>)lst).get(0) instanceof Map, cn(((List<?>)lst).get(0)));
        Object arr = m.get("arr");
        ck("arr 是 List/JSONArray", arr instanceof List, cn(arr));
        ck("arr[0] 是 Map", ((List<?>)arr).get(0) instanceof Map, cn(((List<?>)arr).get(0)));
        ck("direct 是 Map", m.get("direct") instanceof Map, cn(m.get("direct")));
        ck("顶层日期仍是 Date", m.get("topTime") instanceof Date, cn(m.get("topTime")));
        ck("null 原样返回", JsonUtils.toRuleContextValue(null)==null, "null");
        ck("标量原样返回(String)", "x".equals(JsonUtils.toRuleContextValue("x")), "x");
        ck("标量原样返回(Date)", JsonUtils.toRuleContextValue(new Date(1L)) instanceof Date, "Date");
        ck("标量原样返回(BigDecimal)", JsonUtils.toRuleContextValue(new java.math.BigDecimal("1.10")) instanceof java.math.BigDecimal, "BigDecimal");

        // ===================== B1：Map 浅拷贝保类型 =====================
        System.out.println();
        System.out.println("===== B1  new HashMap<>(JSONObject) 保原类型 =====");
        JSONObject row = new JSONObject();
        row.put("t", new Date(1780000000000L)); row.put("n", 7); row.put("b", Boolean.TRUE); row.put("s","x");
        row.put("d", new java.math.BigDecimal("12.34")); row.put("l", 9007199254740993L);
        Map<String,Object> shallow = new HashMap<>(row);
        ck("Date 保持", shallow.get("t") instanceof Date, cn(shallow.get("t")));
        ck("Integer 保持", shallow.get("n") instanceof Integer, cn(shallow.get("n")));
        ck("Boolean 保持", shallow.get("b") instanceof Boolean, cn(shallow.get("b")));
        ck("BigDecimal 保持", shallow.get("d") instanceof java.math.BigDecimal, cn(shallow.get("d")));
        ck("Long 保持", shallow.get("l") instanceof Long, cn(shallow.get("l")));

        // ===================== A：JsonTransferUtil 取路径 =====================
        System.out.println();
        System.out.println("===== A  JsonTransferUtil.getJsonPath（去掉 getClassFromMapping 后）=====");
        JSONArray root = new JSONArray(); root.add(row);
        JSONObject data = new JSONObject(); data.put("root", root);
        JSONObject target = new JSONObject(); target.put("data", data);
        JSONArray got = JsonTransferUtil.getJsonPath(target, "data.root", ".", JSONArray.class);
        ck("取到 JSONArray", got != null && got.size()==1, got==null?"null":("size="+got.size()));
        ck("是同一个实例（按钮才写得回去）", got == root, String.valueOf(got == root));
        JSONObject e = got.getJSONObject(0);
        e.put("operList", "BTN");
        ck("写回后原结构可见", "BTN".equals(target.getJSONObject("data").getJSONArray("root").getJSONObject(0).get("operList")),
           String.valueOf(target.getJSONObject("data").getJSONArray("root").getJSONObject(0).get("operList")));
        ck("行内日期仍是 Date", e.get("t") instanceof Date, cn(e.get("t")));

        // ===================== N2：静态 toJSONString 两版一致 =====================
        System.out.println();
        System.out.println("===== N2  JSON.toJSONString(JSONObject) 输出（跨版本要逐字节相同）=====");
        JSONObject sig = new JSONObject();
        sig.put("t", new Date(1780000000000L)); sig.put("n", 7); sig.put("s","abc");
        String out = JSON.toJSONString(sig);
        System.out.println("  静态写法输出 : " + out);
        System.out.println("  实例写法输出 : " + sig.toJSONString() + "   <- 这个两版不同，所以我们不用它");
        ck("静态输出里日期是时间戳", out.contains("1780000000000"), out);

        System.out.println();
        System.out.println("================ 通过 "+pass+" 项，失败 "+fail+" 项 ================");
        if(fail>0) System.exit(1);
    }
}
