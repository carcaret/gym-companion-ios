Closes #

## Qué cambia


## Tests portados de la PWA (si los hay)

| Test de la PWA (`tests/unit/…` o `tests/e2e/…`) | Test nativo | Notas |
|---|---|---|
| | | |

Tests de la PWA que no aplican y por qué (p. ej. detalles de HTML/CSS):

## Definición de hecho

- [ ] Primero el test (rojo), luego el código (verde), luego refactor.
- [ ] Cada test portado conserva la intención y los casos del original.
- [ ] Ningún test existente borrado ni debilitado (si hace falta, aprobado por el usuario).
- [ ] Cada cosa en su capa: reglas en `Domain`, casos de uso y puertos en `Application`, APIs externas en `Adapters`, vistas finas sobre ViewModels; solo la raíz de composición conoce adaptadores concretos.
- [ ] Tests del paquete en verde en el NAS (Linux) y CI en verde.
- [ ] Capturas del CI revisadas si cambia la UI.
- [ ] Desplegado en el iPhone (log de `ios-signer`: "Instalada la compilación N").
