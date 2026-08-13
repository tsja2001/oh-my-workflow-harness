import com.alibaba.fastjson.*;
import com.alibaba.fastjson.annotation.JSONField;
import com.alibaba.fastjson.serializer.SerializerFeature;
import java.math.BigDecimal;
import java.util.*;

/** 宽口径行为差异探针：每行输出 "编号|结果"，两个版本跑完直接 diff。 */
public class Wide {
    static void p(String id, Object v){ System.out.println(id+"|"+v); }
    static void p(String id, java.util.concurrent.Callable<Object> c){
        try { System.out.println(id+"|"+c.call()); }
        catch (Throwable e){ System.out.println(id+"|EX:"+e.getClass().getName()); }
    }
    static String cn(Object o){ return o==null?"null":o.getClass().getName(); }

    public enum Color { RED, BLUE }

    public static class B {
        private String name="n"; private int age=3; private boolean active=true; private Boolean flag=Boolean.FALSE;
        private Date d=new Date(1780000000000L); private java.sql.Timestamp ts=new java.sql.Timestamp(1780000000000L);
        private java.sql.Date sd=new java.sql.Date(1780000000000L);
        private BigDecimal money=new BigDecimal("12.3400"); private BigDecimal big=new BigDecimal("1E+10");
        private long lng=9007199254740993L; private Long boxLng=null; private String nul=null;
        private Color color=Color.RED; private byte[] bin=new byte[]{1,2,3};
        private List<String> list=Arrays.asList("a","b"); private Map<String,Object> map=new LinkedHashMap<>();
        private java.time.LocalDate ld=java.time.LocalDate.of(2026,6,10);
        private java.time.LocalDateTime ldt=java.time.LocalDateTime.of(2026,6,10,22,0,0);
        @JSONField(name="alias") private String aliased="AV";
        @JSONField(format="yyyy-MM-dd") private Date fmt=new Date(1780000000000L);
        @JSONField(serialize=false) private String hidden="H";
        private transient String tr="T";
        public B(){ map.put("z",1); map.put("a",2); }
        public String getName(){return name;} public int getAge(){return age;}
        public boolean isActive(){return active;} public Boolean getFlag(){return flag;}
        public Date getD(){return d;} public java.sql.Timestamp getTs(){return ts;} public java.sql.Date getSd(){return sd;}
        public BigDecimal getMoney(){return money;} public BigDecimal getBig(){return big;}
        public long getLng(){return lng;} public Long getBoxLng(){return boxLng;} public String getNul(){return nul;}
        public Color getColor(){return color;} public byte[] getBin(){return bin;}
        public List<String> getList(){return list;} public Map<String,Object> getMap(){return map;}
        public java.time.LocalDate getLd(){return ld;} public java.time.LocalDateTime getLdt(){return ldt;}
        public String getAliased(){return aliased;} public Date getFmt(){return fmt;}
        public String getHidden(){return hidden;} public String getTr(){return tr;}
        public void setName(String v){name=v;} public void setAge(int v){age=v;} public void setActive(boolean v){active=v;}
        public void setFlag(Boolean v){flag=v;} public void setD(Date v){d=v;} public void setMoney(BigDecimal v){money=v;}
        public void setLng(long v){lng=v;} public void setNul(String v){nul=v;} public void setColor(Color v){color=v;}
        public void setAliased(String v){aliased=v;} public void setLd(java.time.LocalDate v){ld=v;}
    }
    public static class Cyc { public String id="c1"; public Cyc self; public List<Cyc> peers=new ArrayList<>(); }

    public static void main(String[] x){
        B b=new B();
        // ---- 序列化 ----
        p("S01-bean全量", JSON.toJSONString(b));
        p("S02-null不写", JSON.toJSONString(b));
        p("S03-WriteMapNullValue", JSON.toJSONString(b, SerializerFeature.WriteMapNullValue));
        p("S04-PrettyOff-Date", JSON.toJSONString(b.getD()));
        p("S05-Timestamp", JSON.toJSONString(b.getTs()));
        p("S06-sqlDate", JSON.toJSONString(b.getSd()));
        p("S07-BigDecimal尾零", JSON.toJSONString(new BigDecimal("12.3400")));
        p("S08-BigDecimal科学计数", JSON.toJSONString(new BigDecimal("1E+10")));
        p("S09-double", JSON.toJSONString(1.0d));
        p("S10-float", JSON.toJSONString(1.1f));
        p("S11-long大数", JSON.toJSONString(9007199254740993L));
        p("S12-枚举", JSON.toJSONString(Color.BLUE));
        p("S13-byte数组", JSON.toJSONString(new byte[]{1,2,3}));
        p("S14-null对象", JSON.toJSONString(null));
        p("S15-空Map", JSON.toJSONString(new HashMap<String,Object>()));
        p("S16-LocalDate", JSON.toJSONString(java.time.LocalDate.of(2026,6,10)));
        p("S17-LocalDateTime", JSON.toJSONString(java.time.LocalDateTime.of(2026,6,10,22,0,0)));
        p("S18-字符串转义", JSON.toJSONString("a\"b\\c\n中文/<>&"));
        p("S19-Map非String键", ()->JSON.toJSONString(Collections.singletonMap(1,"v")));
        p("S20-BrowserCompatible", JSON.toJSONString("中文", SerializerFeature.BrowserCompatible));
        p("S21-WriteDateUseDateFormat", JSON.toJSONString(b.getD(), SerializerFeature.WriteDateUseDateFormat));
        p("S22-UseISO8601", JSON.toJSONString(b.getD(), SerializerFeature.UseISO8601DateFormat));
        p("S23-DisableCircularRef", ()->{ Cyc c=new Cyc(); c.self=c; c.peers.add(c);
              return JSON.toJSONString(c, SerializerFeature.DisableCircularReferenceDetect); });
        p("S24-循环引用默认", ()->{ Cyc c=new Cyc(); c.self=c; c.peers.add(c); return JSON.toJSONString(c); });
        p("S25-同一实例两次引用", ()->{ B s=new B(); Map<String,Object> m=new LinkedHashMap<>(); m.put("a",s); m.put("b",s);
              return JSON.toJSONString(m); });
        p("S26-SortField", JSON.toJSONString(b, SerializerFeature.MapSortField));
        p("S27-QuoteFieldNames关", JSON.toJSONString(b.getMap(), SerializerFeature.QuoteFieldNames));
        p("S28-WriteNullStringAsEmpty", JSON.toJSONString(b, SerializerFeature.WriteNullStringAsEmpty));

        // ---- 反序列化 ----
        p("D01-回Bean-Date", ()->{ B r=JSON.parseObject(JSON.toJSONString(b), B.class); return cn(r.getD())+"/"+r.getD().getTime(); });
        p("D02-日期字符串", ()->cn(JSON.parseObject("{\"d\":\"2026-06-10 22:00:00\"}", B.class).getD()));
        p("D03-日期ISO", ()->cn(JSON.parseObject("{\"d\":\"2026-06-10T22:00:00+08:00\"}", B.class).getD()));
        p("D04-日期时间戳", ()->cn(JSON.parseObject("{\"d\":1780000000000}", B.class).getD()));
        p("D05-空串给Date", ()->{ B r=JSON.parseObject("{\"d\":\"\"}", B.class); return String.valueOf(r.getD()); });
        p("D06-空串给int", ()->String.valueOf(JSON.parseObject("{\"age\":\"\"}", B.class).getAge()));
        p("D07-null给int", ()->String.valueOf(JSON.parseObject("{\"age\":null}", B.class).getAge()));
        p("D08-字符串给int", ()->String.valueOf(JSON.parseObject("{\"age\":\"7\"}", B.class).getAge()));
        p("D09-小数给int", ()->String.valueOf(JSON.parseObject("{\"age\":7.9}", B.class).getAge()));
        p("D10-未知字段", ()->JSON.parseObject("{\"zzz\":1,\"age\":5}", B.class).getAge());
        p("D11-枚举大小写", ()->String.valueOf(JSON.parseObject("{\"color\":\"RED\"}", B.class).getColor()));
        p("D12-枚举序号", ()->String.valueOf(JSON.parseObject("{\"color\":0}", B.class).getColor()));
        p("D13-alias回填", ()->JSON.parseObject("{\"alias\":\"X\"}", B.class).getAliased());
        p("D14-BigDecimal", ()->String.valueOf(JSON.parseObject("{\"money\":12.3400}", B.class).getMoney()));
        p("D15-大long不丢精度", ()->String.valueOf(JSON.parseObject("{\"lng\":9007199254740993}", B.class).getLng()));
        p("D16-布尔0/1", ()->String.valueOf(JSON.parseObject("{\"active\":1}", B.class).isActive()));
        p("D17-布尔字符串", ()->String.valueOf(JSON.parseObject("{\"active\":\"true\"}", B.class).isActive()));
        p("D18-parse裸对象类型", ()->cn(JSON.parse("{\"a\":1}")));
        p("D19-parse数字类型", ()->cn(JSON.parseObject("{\"a\":1}").get("a")));
        p("D20-parse大数类型", ()->cn(JSON.parseObject("{\"a\":9007199254740993}").get("a")));
        p("D21-parse小数类型", ()->cn(JSON.parseObject("{\"a\":1.5}").get("a")));
        p("D22-parse字符串日期类型", ()->cn(JSON.parseObject("{\"a\":\"2026-06-10 22:00:00\"}").get("a")));
        p("D23-JSONObject有序?", ()->{ JSONObject j=JSON.parseObject("{\"z\":1,\"a\":2,\"m\":3}"); return j.keySet().toString(); });
        p("D24-new JSONObject有序?", ()->{ JSONObject j=new JSONObject(); j.put("z",1); j.put("a",2); j.put("m",3); return j.keySet().toString(); });
        p("D25-getString非串", ()->JSON.parseObject("{\"a\":1}").getString("a"));
        p("D26-getDate从串", ()->cn(JSON.parseObject("{\"a\":\"2026-06-10 22:00:00\"}").getDate("a")));
        p("D27-getDate从数", ()->cn(JSON.parseObject("{\"a\":1780000000000}").getDate("a")));
        p("D28-getInteger从串", ()->String.valueOf(JSON.parseObject("{\"a\":\"5\"}").getInteger("a")));
        p("D29-getBigDecimal", ()->String.valueOf(JSON.parseObject("{\"a\":12.3400}").getBigDecimal("a")));
        p("D30-getBooleanValue空", ()->String.valueOf(JSON.parseObject("{}").getBooleanValue("a")));
        p("D31-非法JSON", ()->{ try{ JSON.parseObject("{bad"); return "no-ex"; }catch(Throwable t){ return t.getClass().getName(); } });
        p("D32-单引号JSON", ()->{ try{ return String.valueOf(JSON.parseObject("{'a':1}").get("a")); }catch(Throwable t){ return "EX:"+t.getClass().getSimpleName(); } });
        p("D33-尾逗号", ()->{ try{ return String.valueOf(JSON.parseObject("{\"a\":1,}").get("a")); }catch(Throwable t){ return "EX:"+t.getClass().getSimpleName(); } });
        p("D34-parseArray泛型", ()->{ List<B> l=JSON.parseArray("[{\"age\":1},{\"age\":2}]", B.class); return l.size()+"/"+cn(l.get(0)); });
        p("D35-TypeReference-List", ()->{ List<B> l=JSON.parseObject("[{\"age\":1}]", new TypeReference<List<B>>(){}); return cn(l.get(0)); });
        p("D36-TypeReference-MapBean", ()->{ Map<String,B> m=JSON.parseObject("{\"k\":{\"age\":1}}", new TypeReference<Map<String,B>>(){}); return cn(m.get("k")); });
        p("D37-JSONArray元素类型", ()->cn(JSON.parseArray("[{\"a\":1}]").get(0)));
        p("D38-toJavaObject-List", ()->{ JSONArray a=JSON.parseArray("[{\"age\":1}]"); return cn(a.toJavaList(B.class).get(0)); });
        p("D39-JSONObject.getObject", ()->cn(JSON.parseObject("{\"k\":{\"age\":1}}").getObject("k", B.class)));
        p("D40-嵌套getJSONObject", ()->cn(JSON.parseObject("{\"k\":{\"a\":1}}").getJSONObject("k")));

        // ---- toJSON 家族 ----
        p("T01-toJSON顶层", ()->cn(JSON.toJSON(b)));
        p("T02-toJSON-Map值Bean", ()->{ Map<String,B> m=new HashMap<>(); m.put("k",new B());
              return cn(((Map<?,?>)JSON.toJSON(m)).get("k")); });
        p("T03-toJSON-List元素Bean", ()->cn(((List<?>)JSON.toJSON(Arrays.asList(new B()))).get(0)));
        p("T04-toJSON-数组Bean", ()->cn(JSON.toJSON(new B[]{new B()})));
        p("T05-toJSON-Date字段", ()->cn(((Map<?,?>)JSON.toJSON(b)).get("d")));
        p("T06-toJavaObject-TR-Map", ()->{ JSONObject j=new JSONObject(); j.put("t",new Date(1L));
              Map<?,?> m=(Map<?,?>) j.toJavaObject(new TypeReference<Map<String,Object>>(){});
              return cn(m.get("t")); });
        p("T07-toJavaObject-MapClass", ()->cn(((Map<?,?>)JSON.toJavaObject(JSON.parseObject("{}"),Map.class))));
        p("T08-JSONObject强转JSON", ()->String.valueOf(new JSONObject() instanceof JSON));
        p("T09-JSONArray强转JSON", ()->String.valueOf(new JSONArray() instanceof JSON));
        p("T10-JSONObject是Map", ()->String.valueOf(new JSONObject() instanceof Map));
        p("T11-toJSONString(JSONObject)", ()->{ JSONObject j=new JSONObject(); j.put("d",new Date(1780000000000L)); return j.toJSONString(); });
        p("T12-JSONObject.put后get类型", ()->{ JSONObject j=new JSONObject(); j.put("d",new Date(1L)); return cn(j.get("d")); });
        p("T13-JSONValidator", ()->{ JSONValidator v=JSONValidator.from("{\"a\":1}"); return v.validate()+"/"+v.getType(); });
        p("T14-isValidArray", ()->String.valueOf(JSON.isValidArray("[1]")));
        p("T15-toJSONBytes长度", ()->String.valueOf(JSON.toJSONBytes(b, new SerializerFeature[0]).length));
    }
}
