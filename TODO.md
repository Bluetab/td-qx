## TODO:

[x] Configurar el td-core para que esté bloqueado el push a main
[x] añadir elastic al td-k8s de td-qx
[x] user with any permission to create should see create new button
[x] user witout any create, shouldnt view create
[x] actions should do "all domains" permissions for each action

## JIRA:

[ ] Hacer una tarea de migración, de los filtros en td-web-modules

### QualityControls

[ ] migración de filtros y elastic search en los servicios.
[ ] Mirar lo del vacumm
[ ] el core tira de 3 librerias revisar
[ ] editar los domains
[ ] Jerarquia no funciona en los filtros
[ ] la tabla no es configurable ( utilizar contexto de columnas que este desde td-web englobe toda la aplicacion)
[ ] Borrado fisico de QC deprecado
[ ] deuda tecnica los filtros globales y de usuario
[ ] indice de publicadas y permiso de ver sólo publicadas?
[ ] permite guardar sin seleccionar la funcion
[ ] meter confirmación cuando se depreca que se va a eliminar el draft
[ ] tests de front
[ ] variables de entorno de elastic search

### Things to warn

- Deprecation with draft will remove the draft
- Incoerencia al guardar drafts. ver como hacer la validación más lista
- no hay vistas para deprecados o sólo para las publicadas
