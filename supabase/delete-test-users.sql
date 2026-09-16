-- =====================================================
-- Borrar usuarios de TEST: cualquier perfil cuyo nombre+sección NO esté
-- en el roster real del salón. Al borrar de auth.users, se elimina en
-- cascada TODO lo suyo (perfil, calificaciones, ships, protestas,
-- notificaciones, mensajes, etc.).
-- =====================================================

-- 1) (opcional) Mirá primero a quiénes va a borrar:
-- select p.user_id, p.name, p.section
-- from public.profiles p
-- where (p.name, p.section) not in (
--   ('Amaya','A'),('Deleón','A'),('Magaña','A'),('Gerardo','A'),('Osegueda','A'),('Fabricio','A'),
--   ('Jaime','A'),('Eduardo','A'),('Alejandro','A'),('Valentina','A'),('Hana','A'),('Abril','A'),('Sofía','A'),
--   ('Iglesias','B'),('Mateo','B'),('Alejandro','B'),('Javier','B'),('Sophia','B'),('Marcela','B'),
--   ('Julietta','B'),('Andrea','B'),('Suil','B'),('Roberto','B'),('Carlos','B'),('Josué','B'),('Lucas','B'),('Lucía','B')
-- );

-- 2) Borrar de verdad (cascada):
delete from auth.users u
where u.id in (
  select p.user_id from public.profiles p
  where (p.name, p.section) not in (
    ('Amaya','A'),('Deleón','A'),('Magaña','A'),('Gerardo','A'),('Osegueda','A'),('Fabricio','A'),
    ('Jaime','A'),('Eduardo','A'),('Alejandro','A'),('Valentina','A'),('Hana','A'),('Abril','A'),('Sofía','A'),
    ('Iglesias','B'),('Mateo','B'),('Alejandro','B'),('Javier','B'),('Sophia','B'),('Marcela','B'),
    ('Julietta','B'),('Andrea','B'),('Suil','B'),('Roberto','B'),('Carlos','B'),('Josué','B'),('Lucas','B'),('Lucía','B')
  )
);
