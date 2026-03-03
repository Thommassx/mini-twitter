# Mini Twitter - Projeto de Banco de Dados (MySQL)

Entregáveis implementados:

- `schema.sql`: criação do banco, tabelas, constraints, índices, triggers de validação e auditoria.
- `procedures.sql`: procedures para CRUD controlado de usuários, posts, comentários e likes.
- `tests.sql`: carga de dados, cenários de falha controlada e consultas de processamento.

## Ordem de execução

```sql
SOURCE schema.sql;
SOURCE procedures.sql;
SOURCE tests.sql;
```

## DER (visão textual)

- `users (1) ---- (N) posts`
- `users (1) ---- (N) comments`
- `posts (1) ---- (N) comments`
- `users (N) ---- (N) posts` via `likes`
- `audit_log` registra operações de `users`, `posts`, `comments` e `likes`.

## Observações

- Likes duplicados são impedidos por `PRIMARY KEY (user_id, post_id)` e trigger.
- Validações obrigatórias (e-mail, conteúdo de post/comentário) usam `SIGNAL SQLSTATE '45000'`.
- Auditoria registra `INSERT`, `UPDATE` e `DELETE` com detalhes em JSON.
