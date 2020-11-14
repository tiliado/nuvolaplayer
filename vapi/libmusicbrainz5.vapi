[CCode (cheader_filename="musicbrainz5/mb5_c.h")]
namespace Mb5 {


[Compact]
[CCode(cname="void", free_function="mb5_query_delete", has_type_id=false)]
public class Query {
    public Query(string user_agent, string? server=null, int port=0);
    public Metadata? query(string entity, string? id, string? resource, [CCode(array_length_pos=3.5)] string[] names, [CCode(array_length_pos=3.5)] string[] values);
    public Result get_lastresult();
}

[Compact]
[CCode(cname="void", free_function="mb5_metadata_delete", has_type_id=false)]
public class Metadata {
    public unowned WorkList? get_worklist();
    public unowned Work? get_work();
}

[Compact]
[CCode(cname="void", free_function="mb5_work_list_delete", has_type_id=false)]
public class WorkList {
    public int size {[CCode(cname="mb5_work_list_size")] get;}
    [CCode(cname="mb5_work_list_item")]
    public unowned Work? get(int index);
}

[Compact]
[CCode(cname="void", free_function="mb5_work_delete", has_type_id=false)]
public class Work {
    public int get_id(uint8[] buffer);
    public int get_title(uint8[] buffer);
    public unowned RelationListList? get_relationlistlist();
}

[Compact]
[CCode(cname="void", free_function="mb5_relationlist_list_delete", has_type_id=false)]
public class RelationListList {
    public int size {[CCode(cname="mb5_relationlist_list_size")] get;}
    [CCode(cname="mb5_relationlist_list_item")]
    public unowned RelationList? get(int index);
}

[Compact]
[CCode(cname="void", free_function="mb5_relation_list_delete", has_type_id=false)]
public class RelationList {
    public int size {[CCode(cname="mb5_relation_list_size")] get;}
    [CCode(cname="mb5_relation_list_item")]
    public unowned Relation? get(int index);
}

[Compact]
[CCode(cname="void", free_function="mb5_relation_delete", has_type_id=false)]
public class Relation {
    public int get_target(uint8[] buffer);
    public int get_type(uint8[] buffer);
}

[CCode(cname="tQueryResult", cprefix="eQuery_", has_type_id=false)]
public enum Result {
        Success,
        ConnectionError,
        Timeout,
        AuthenticationError,
        FetchError,
        RequestError,
        ResourceNotFound,
}

} // namespace Mb5
