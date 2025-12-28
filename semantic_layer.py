import json, sqlite3
from typing import Dict, List, Any

def _pluralize(name: str) -> str:
    if name.endswith('y'): return name[:-1] + 'ies'
    if not name.endswith('s'): return name + 's'
    return name

def _singularize(name: str) -> str:
    if name.endswith('ies'): return name[:-3] + 'y'
    if name.endswith('s'): return name[:-1]
    return name

def inspect_schema(db_path: str) -> Dict[str, Any]:
    conn = sqlite3.connect(db_path); conn.row_factory = sqlite3.Row; cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    tables = [r['name'] for r in cur.fetchall()]
    columns = {}; fks = {}
    for t in tables:
        cur.execute(f"PRAGMA table_info('{t}')"); columns[t] = [dict(r) for r in cur.fetchall()]
        cur.execute(f"PRAGMA foreign_key_list('{t}')"); fks[t] = [dict(r) for r in cur.fetchall()]
    conn.close()
    return {'tables': tables, 'columns': columns, 'foreign_keys': fks}

def infer_relationships(schema: Dict[str, Any]) -> Dict[str, Any]:
    tables, columns, fks = schema['tables'], schema['columns'], schema['foreign_keys']
    relationships: List[Dict[str, Any]] = []
    for src, fk_list in fks.items():
        for fk in fk_list:
            dst = fk.get('table'); frm = fk.get('from'); to = fk.get('to') or 'id'
            if dst: relationships.append({'type':'fk','from_table':src,'from_column':frm,'to_table':dst,'to_column':to})
    for t in tables:
        for col in columns[t]:
            name = col['name']
            if name.endswith('_id') and name != 'id':
                cand = name[:-3]
                cands = {cand, _pluralize(cand), _singularize(cand)}
                for other in tables:
                    if other in cands or _singularize(other) in cands or _pluralize(other) in cands:
                        if not any(r for r in relationships if r['from_table']==t and r['to_table']==other and r['from_column']==name):
                            relationships.append({'type':'heuristic_id','from_table':t,'from_column':name,'to_table':other,'to_column':'id'})
    for t in tables:
        targets = {r['table'] for r in fks.get(t, [])}
        if len(targets) >= 2 and all(c['name'].endswith('_id') for c in columns[t] if c['name'].endswith('_id')):
            relationships.append({'type':'bridge_hint','bridge_table':t,'connects':list(targets)[:2]})
    return {'relationships': relationships}

def semantic_summary(schema: Dict[str, Any], rels: Dict[str, Any]) -> str:
    lines = ['Tablas: ' + ', '.join(schema['tables'])]
    for t in schema['tables']:
        cols = [c['name'] for c in schema['columns'][t]]
        lines.append(f" - {t}: columnas = {', '.join(cols)}")
    if rels['relationships']:
        lines.append('Relaciones inferidas:')
        for r in rels['relationships']:
            if r.get('type') == 'bridge_hint':
                lines.append(f"   * [bridge] {r['bridge_table']} conecta {r['connects']}")
            else:
                lines.append(f"   * {r['from_table']}.{r['from_column']} -> {r['to_table']}.{r['to_column']} ({r['type']})")
    return '\n'.join(lines)

def build_semantic_layer(db_path: str) -> Dict[str, Any]:
    schema = inspect_schema(db_path); rels = infer_relationships(schema); summary = semantic_summary(schema, rels)
    return {'schema': schema, 'relationships': rels, 'summary': summary}
