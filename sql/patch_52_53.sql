-- Updating the schema version:

UPDATE meta SET meta_value = 53 where meta_key = "schema_version";


-- A single mapping_session is the event when mapping between two given releases rel_from and rel_to
-- for a particular class type ('family' or 'tree') is loaded.
-- The whole event is thought to happen momentarily at 'when_mapped' (used for sorting in historical order).

CREATE TABLE mapping_session (
    mapping_session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type               ENUM('family', 'tree'),
    when_mapped        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rel_from           INT UNSIGNED,
    rel_to             INT UNSIGNED,
    PRIMARY KEY ( mapping_session_id ),
    UNIQUE KEY  ( type, rel_from, rel_to )
);


-- This table keeps the history of stable_id changes from one release to another.
-- 
-- The primary key 'object' describes a set of members migrating from stable_id_from to stable_id_to.
-- Their volume (related to the 'shared_size' of the new class) is reflected by the fractional 'contribution' field.
-- 
-- Since both stable_ids are listed in the primary key,
-- they are not allowed to be NULLs. We shall treat empty strings as NULLs.
--
-- If stable_id_from is empty, it means these members are newcomers into the new release.
-- If stable_id_to is empty, it means these previously known members are disappearing in the new release.
-- If both neither stable_id_from nor stable_id_to is empty, these members are truly migrating.

CREATE TABLE stable_id_history (
    mapping_session_id INT UNSIGNED NOT NULL,
    stable_id_from     VARCHAR(40) NOT NULL DEFAULT '',
    version_from       INT UNSIGNED NULL DEFAULT NULL,
    stable_id_to       VARCHAR(40) NOT NULL DEFAULT '',
    version_to         INT UNSIGNED NULL DEFAULT NULL,
    contribution       FLOAT,
    PRIMARY KEY ( mapping_session_id, stable_id_from, stable_id_to )
);


-- Protein trees will now have stable_ids:

CREATE TABLE protein_tree_stable_id (
    node_id   INT(10) UNSIGNED NOT NULL,
    stable_id VARCHAR(40)  NOT NULL,
    version   INT UNSIGNED NOT NULL,
    PRIMARY KEY ( node_id ),
    UNIQUE KEY ( stable_id )
);

-- Family stable_ids will now have versions:

ALTER TABLE family ADD COLUMN version INT UNSIGNED;

