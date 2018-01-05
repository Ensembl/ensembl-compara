-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# extending analysis.module field to 255 characters (used to be 80, which is too limiting):
ALTER TABLE analysis MODIFY COLUMN module varchar(255);

# Done to alter the mapping session code
alter table mapping_session add column prefix CHAR(4);
update mapping_session set prefix = 'ENS';
alter table mapping_session alter column prefix CHAR(4) NOT NULL;

alter table mapping_session drop index `type`;
alter table mapping_session add index `type` (`type`,`rel_from`,`rel_to`, `prefix`);