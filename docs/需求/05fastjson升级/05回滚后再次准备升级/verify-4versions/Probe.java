import com.alibaba.fastjson.*;
import java.util.*;
import java.lang.reflect.*;

public class Probe {
    public static class Inner {
        private String content; private Date bizTime;
        public String getContent(){return content;} public void setContent(String c){content=c;}
        public Date getBizTime(){return bizTime;} public void setBizTime(Date d){bizTime=d;}
    }
    public static class Outer {
        private String code; private Date topTime; private Map<String,Inner> detailMap; private List<Inner> list;
        public String getCode(){return code;} public void setCode(String c){code=c;}
        public Date getTopTime(){return topTime;} public void setTopTime(Date d){topTime=d;}
        public Map<String,Inner> getDetailMap(){return detailMap;} public void setDetailMap(Map<String,Inner> m){detailMap=m;}
        public List<Inner> getList(){return list;} public void setList(List<Inner> l){list=l;}
    }

    static String t(Object o){ return o==null? "null" : o.getClass().getName(); }
    static void line(String k, String v){ System.out.println(String.format("%-46s %s", k, v)); }

    public static void main(String[] a) throws Exception {
        Date d = new Date(1780000000000L);
        Inner in = new Inner(); in.setContent("hello"); in.setBizTime(d);
        Outer out = new Outer(); out.setCode("C1"); out.setTopTime(d);
        Map<String,Inner> dm = new HashMap<>(); dm.put("k1", in); out.setDetailMap(dm);
        out.setList(Arrays.asList(in));

        System.out.println("=========== fastjson 版本 ===========");
        line("com.alibaba.fastjson.JSON 来源jar", JSON.class.getProtectionDomain().getCodeSource().getLocation().toString());
        try { Class<?> c2 = Class.forName("com.alibaba.fastjson2.JSON");
              line("底层 fastjson2 存在", "是 -> "+c2.getProtectionDomain().getCodeSource().getLocation());
        } catch (Throwable e){ line("底层 fastjson2 存在", "否（纯 1.x）"); }

        System.out.println();
        System.out.println("=========== T1 日期默认序列化格式（影响前端/接口报文）===========");
        line("JSON.toJSONString(Date)", JSON.toJSONString(d));
        line("JSON.toJSONString(Bean含Date)", JSON.toJSONString(out).substring(0, Math.min(120, JSON.toJSONString(out).length())));

        System.out.println();
        System.out.println("=========== T2 JSONObject -> Map<String,Object> 泛型转换（Source 日期变String根因）===========");
        JSONObject row = new JSONObject();
        row.put("t", d); row.put("n", Integer.valueOf(7)); row.put("b", Boolean.TRUE); row.put("s","x");
        try {
            Map<String,Object> m = row.toJavaObject(new TypeReference<Map<String,Object>>(){});
            line("toJavaObject(TypeReference<Map>) 日期类型", t(m.get("t")));
            line("  数字类型", t(m.get("n")));
            line("  布尔类型", t(m.get("b")));
        } catch (Throwable e){ line("toJavaObject(TypeReference<Map>)", "异常:"+e); }
        try {
            Map<String,Object> m2 = new HashMap<>(row);
            line("new HashMap<>(JSONObject) 日期类型 [修法]", t(m2.get("t")));
        } catch (Throwable e){ line("new HashMap<>(JSONObject)", "异常:"+e); }
        try {
            Object mm = JSON.toJavaObject((JSON) row, Map.class);
            line("toJavaObject(.., Map.class) 日期类型", t(((Map<?,?>)mm).get("t")));
        } catch (Throwable e){ line("toJavaObject(..,Map.class)", "异常:"+e); }

        System.out.println();
        System.out.println("=========== T3 JSON.toJSON(Bean) 是否递归转 Map（IFS QLExpress 根因）===========");
        Object j = JSON.toJSON(out);
        line("顶层类型", t(j));
        Object dmo = ((Map<?,?>) j).get("detailMap");
        line("detailMap 类型", t(dmo));
        Object innerObj = ((Map<?,?>) dmo).get("k1");
        line("detailMap.k1 类型（脚本要能 .get）", t(innerObj));
        line("  k1 是否是 Map(脚本 .get 可用)", (innerObj instanceof Map) ? "是 ✅" : "否 ❌(会报 no method get(String))");
        Object lo = ((Map<?,?>) j).get("list");
        Object l0 = (lo instanceof List) ? ((List<?>)lo).get(0) : null;
        line("list[0] 类型", t(l0));
        line("顶层 topTime 类型", t(((Map<?,?>) j).get("topTime")));

        System.out.println();
        System.out.println("=========== T4 1.x 独有 API 是否还在 ===========");
        try { Method m = com.alibaba.fastjson.parser.ParserConfig.class.getMethod("getClassFromMapping", String.class);
              line("ParserConfig.getClassFromMapping", "存在 ✅ "+m); }
        catch (Throwable e){ line("ParserConfig.getClassFromMapping", "不存在 ❌ (1.x代码会编译/运行失败)"); }
        try { JSON.class.getMethod("toJSONBytes", Object.class);
              line("JSON.toJSONBytes(Object) 单参", "存在（2.x特征）"); }
        catch (Throwable e){ line("JSON.toJSONBytes(Object) 单参", "不存在（1.x特征，只有变参版）"); }

        System.out.println();
        System.out.println("=========== T5 SafeMode 属性是否被读取 ===========");
        line("System fastjson.parser.safeMode", String.valueOf(System.getProperty("fastjson.parser.safeMode")));
        line("System fastjson2.parser.safeMode", String.valueOf(System.getProperty("fastjson2.parser.safeMode")));
        try {
            Class<?> p = Class.forName("com.alibaba.fastjson2.reader.ObjectReaderProvider");
            Field f = null;
            for (Field ff : p.getDeclaredFields()) if (ff.getName().toLowerCase().contains("safemode")) f = ff;
            if (f != null){ f.setAccessible(true); line("fastjson2 内部 SAFE_MODE 实际值", String.valueOf(f.get(null))); }
            else line("fastjson2 内部 SAFE_MODE 字段", "未找到同名字段");
        } catch (Throwable e){ line("fastjson2 ObjectReaderProvider", "不可用（纯1.x）: "+e.getClass().getSimpleName()); }
        try {
            Field f = com.alibaba.fastjson.parser.ParserConfig.class.getDeclaredField("safeMode");
            f.setAccessible(true);
            line("1.x ParserConfig.global.safeMode", String.valueOf(f.get(com.alibaba.fastjson.parser.ParserConfig.getGlobalInstance())));
        } catch (Throwable e){ line("1.x ParserConfig.safeMode 字段", "取不到: "+e.getClass().getSimpleName()); }

        System.out.println();
        System.out.println("=========== T6 反序列化回 Bean（日期字符串能否回填 Date）===========");
        String js = JSON.toJSONString(out);
        Outer back = JSON.parseObject(js, Outer.class);
        line("parseObject 回 Bean topTime", t(back.getTopTime()) + " = " + back.getTopTime());
    }
}
