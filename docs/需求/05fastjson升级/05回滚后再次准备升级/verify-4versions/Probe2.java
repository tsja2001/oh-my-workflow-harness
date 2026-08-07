import com.alibaba.fastjson.*;
import java.util.*;

public class Probe2 {
    public static class Leaf { private String c=" L "; private Date t=new Date(1780000000000L);
        public String getC(){return c;} public Date getT(){return t;} }
    public static class Root {
        private Leaf direct = new Leaf();                       // 直接嵌套 Bean 字段
        private Map<String,Leaf> mapOfBean = new HashMap<>();   // Map<String,Bean>
        private Map<String,Object> mapOfObj = new HashMap<>();  // Map<String,Object> 里放 Bean
        private List<Leaf> listOfBean = new ArrayList<>();      // List<Bean>
        private Leaf[] arrOfBean;                               // Bean[]
        public Root(){ Leaf a=new Leaf(); mapOfBean.put("k",new Leaf()); mapOfObj.put("k",new Leaf());
                       listOfBean.add(new Leaf()); arrOfBean=new Leaf[]{new Leaf()}; }
        public Leaf getDirect(){return direct;}
        public Map<String,Leaf> getMapOfBean(){return mapOfBean;}
        public Map<String,Object> getMapOfObj(){return mapOfObj;}
        public List<Leaf> getListOfBean(){return listOfBean;}
        public Leaf[] getArrOfBean(){return arrOfBean;}
    }
    static String t(Object o){ return o==null?"null":o.getClass().getSimpleName(); }
    static String ok(Object o){ return (o instanceof Map)?"Map ✅可.get()":"❌"+t(o); }

    public static void main(String[] a){
        System.out.println("jar = "+JSON.class.getProtectionDomain().getCodeSource().getLocation());
        Map<?,?> j = (Map<?,?>) JSON.toJSON(new Root());
        System.out.println("--- JSON.toJSON(Root) 之后各层类型 ---");
        System.out.println("  direct(直接嵌套Bean字段)      : "+ok(j.get("direct")));
        Object mb=j.get("mapOfBean");
        System.out.println("  mapOfBean 容器               : "+t(mb));
        System.out.println("  mapOfBean.k                  : "+ok(((Map<?,?>)mb).get("k")));
        Object mo=j.get("mapOfObj");
        System.out.println("  mapOfObj 容器                : "+t(mo));
        System.out.println("  mapOfObj.k                   : "+ok(((Map<?,?>)mo).get("k")));
        Object lb=j.get("listOfBean");
        System.out.println("  listOfBean 容器              : "+t(lb));
        System.out.println("  listOfBean[0]                : "+ok(((List<?>)lb).get(0)));
        Object ab=j.get("arrOfBean");
        System.out.println("  arrOfBean 容器               : "+t(ab));
        System.out.println("  arrOfBean[0]                 : "+ok(((List<?>)ab).get(0)));

        System.out.println("--- 对照：JSON.parse(JSON.toJSONString(Root)) 文本往返 ---");
        Map<?,?> k = (Map<?,?>) JSON.parse(JSON.toJSONString(new Root()));
        System.out.println("  direct                       : "+ok(k.get("direct")));
        Object dl=((Map<?,?>)k.get("direct")).get("t");
        System.out.println("  direct.t 日期类型             : "+t(dl)+"  <- 文本往返后日期是否还是Date");
    }
}
