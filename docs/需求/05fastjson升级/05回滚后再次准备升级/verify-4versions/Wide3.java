import com.alibaba.fastjson.*;
import java.util.*;

/** 关键链路：GlobalResponseHandler 走 JSON.toJSON(body) 之后，各字段变成什么 Java 类型
 *  （最终由 Jackson 序列化这些类型输出给前端，所以类型决定前端看到什么） */
public class Wide3 {
    static void p(String id, Object v){ System.out.println(id+"|"+v); }
    static String cn(Object o){ return o==null?"null":o.getClass().getName(); }
    public static class VO {
        private Date d=new Date(1780000000000L);
        private java.sql.Timestamp ts=new java.sql.Timestamp(1780000000000L);
        private java.time.LocalDate ld=java.time.LocalDate.of(2026,6,10);
        private java.time.LocalDateTime ldt=java.time.LocalDateTime.of(2026,6,10,22,0,0);
        private java.math.BigDecimal money=new java.math.BigDecimal("12.3400");
        private Long lng=9007199254740993L;
        private Integer i=5;
        private String s="x";
        private Boolean b=Boolean.TRUE;
        public Date getD(){return d;} public java.sql.Timestamp getTs(){return ts;}
        public java.time.LocalDate getLd(){return ld;} public java.time.LocalDateTime getLdt(){return ldt;}
        public java.math.BigDecimal getMoney(){return money;} public Long getLng(){return lng;}
        public Integer getI(){return i;} public String getS(){return s;} public Boolean getB(){return b;}
    }
    // 模拟 Result<PageList<VO>> 这种真实返回结构
    public static class Page { private List<VO> root=Arrays.asList(new VO()); private int total=1;
        public List<VO> getRoot(){return root;} public int getTotal(){return total;} }
    public static class Result { private boolean status=true; private Page data=new Page();
        public boolean isStatus(){return status;} public Page getData(){return data;} }

    public static void main(String[] a){
        Object o = JSON.toJSON(new Result());
        p("G01-顶层类型", cn(o));
        Map<?,?> m=(Map<?,?>)o;
        Object data=m.get("data");
        p("G02-data类型", cn(data));
        Object root=((Map<?,?>)data).get("root");
        p("G03-root类型", cn(root));
        Object row=((List<?>)root).get(0);
        p("G04-行类型", cn(row));
        if (row instanceof Map){
            Map<?,?> r=(Map<?,?>)row;
            for (String k : new String[]{"d","ts","ld","ldt","money","lng","i","s","b"})
                p("G10-字段"+k, cn(r.get(k))+" = "+r.get(k));
        } else {
            p("G10-行不是Map","无法逐字段取值");
        }
        // 单对象分支
        Object o2=JSON.toJSON(new VO());
        Map<?,?> r2=(Map<?,?>)o2;
        for (String k : new String[]{"d","ts","ld","ldt","money","lng"})
            p("G20-单对象"+k, cn(r2.get(k))+" = "+r2.get(k));
    }
}
