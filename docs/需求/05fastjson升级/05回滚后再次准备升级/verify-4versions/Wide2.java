import com.alibaba.fastjson.*;
import java.util.*;

/** 针对新发现的两个雷，精确定边界 */
public class Wide2 {
    static void p(String id, Object v){ System.out.println(id+"|"+v); }
    public static class WithTime {
        public Date d=new Date(1780000000000L);
        public java.time.LocalDate ld=java.time.LocalDate.of(2026,6,10);
        public java.time.LocalDateTime ldt=java.time.LocalDateTime.of(2026,6,10,22,0,0);
        public java.time.LocalTime lt=java.time.LocalTime.of(22,0,0);
    }
    public static class DefVal { public int n=3; public Integer bn=3; public String s="def"; public long l=3L; public boolean b=true; }

    public static void main(String[] a){
        Date d=new Date(1780000000000L);
        // ===== 雷1：JSONObject 里的 Date，各种输出路径 =====
        JSONObject jo=new JSONObject(); jo.put("d", d);
        p("R1-实例.toJSONString()",      jo.toJSONString());
        p("R2-静态JSON.toJSONString(jo)", JSON.toJSONString(jo));
        p("R3-静态JSONObject.toJSONString(jo)", JSONObject.toJSONString(jo));
        p("R4-jo.toString()",            jo.toString());
        p("R5-String.valueOf(jo)",       String.valueOf(jo));
        p("R6-嵌进外层再静态输出",        JSON.toJSONString(Collections.singletonMap("in", jo)));
        JSONArray ja=new JSONArray(); ja.add(jo);
        p("R7-JSONArray实例.toJSONString()", ja.toJSONString());
        p("R8-静态JSON.toJSONString(ja)",    JSON.toJSONString(ja));
        Map<String,Object> hm=new HashMap<>(); hm.put("d", d);
        p("R9-普通HashMap静态输出",      JSON.toJSONString(hm));
        p("R10-普通HashMap-JSON.toJSON再静态", JSON.toJSONString(JSON.toJSON(hm)));
        p("R11-Bean静态输出",            JSON.toJSONString(new WithTime()));
        p("R12-Bean先toJSON再静态",      JSON.toJSONString(JSON.toJSON(new WithTime())));
        p("R13-Bean先toJSON再实例toJSONString", ((JSONObject)JSON.toJSON(new WithTime())).toJSONString());

        // ===== 雷2：java.time.* 各类型 =====
        p("R20-LocalDate",     JSON.toJSONString(java.time.LocalDate.of(2026,6,10)));
        p("R21-LocalDateTime", JSON.toJSONString(java.time.LocalDateTime.of(2026,6,10,22,0,0)));
        p("R22-LocalTime",     JSON.toJSONString(java.time.LocalTime.of(22,0,0)));
        p("R23-Instant",       JSON.toJSONString(java.time.Instant.ofEpochMilli(1780000000000L)));
        p("R24-ZonedDateTime", JSON.toJSONString(java.time.ZonedDateTime.of(2026,6,10,22,0,0,0,java.time.ZoneId.of("Asia/Shanghai"))));
        p("R25-Bean含java.time", JSON.toJSONString(new WithTime()));
        String r26; try { r26 = String.valueOf(JSON.parseObject("{\"ld\":\"2026-06-10\"}", WithTime.class).ld); }
                    catch (Throwable t){ r26 = "EX:"+t.getClass().getSimpleName(); }
        p("R26-回读LocalDate(字符串)", r26);
        String r27; try { r27 = String.valueOf(JSON.parseObject("{\"ld\":1781020800000}", WithTime.class).ld); }
                    catch (Throwable t){ r27 = "EX:"+t.getClass().getSimpleName(); }
        p("R27-回读LocalDate(时间戳)", r27);

        // ===== 雷3：反序列化时基本类型默认值 =====
        p("R30-空串给int",   JSON.parseObject("{\"n\":\"\"}", DefVal.class).n);
        p("R31-null给int",   JSON.parseObject("{\"n\":null}", DefVal.class).n);
        p("R32-null给Integer", String.valueOf(JSON.parseObject("{\"bn\":null}", DefVal.class).bn));
        p("R33-null给String",  String.valueOf(JSON.parseObject("{\"s\":null}", DefVal.class).s));
        p("R34-null给long",  JSON.parseObject("{\"l\":null}", DefVal.class).l);
        p("R35-null给boolean", JSON.parseObject("{\"b\":null}", DefVal.class).b);
        p("R36-字段缺失给int", JSON.parseObject("{}", DefVal.class).n);
        p("R37-空串给Integer", String.valueOf(JSON.parseObject("{\"bn\":\"\"}", DefVal.class).bn));
    }
}
