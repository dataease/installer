ALTER SYSTEM ADD BACKEND 'doris-be:9050';
CREATE DATABASE dataease;
SET PASSWORD FOR 'root' = PASSWORD('Password123@doris');
SET GLOBAL enable_spilling = true;