# extending analysis.module field to 255 characters (used to be 80, which is too limiting):
ALTER TABLE analysis MODIFY COLUMN module varchar(255);

