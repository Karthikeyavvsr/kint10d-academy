CREATE TABLE `progress` (
	`owner` text NOT NULL,
	`key` text NOT NULL,
	`value` text NOT NULL,
	`revision` integer DEFAULT 1 NOT NULL,
	`updated` text NOT NULL,
	PRIMARY KEY(`owner`, `key`)
);
