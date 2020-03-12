CREATE TABLE `main_table` (
    `id`      INT NOT NULL,
    `grp`     VARCHAR(20) DEFAULT NULL,
    `value`   INT DEFAULT NULL,
    `comment` TEXT DEFAULT NULL,

    PRIMARY KEY (id)
);
