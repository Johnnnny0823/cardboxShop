-- Commercial TCG/PTCG Feature Upgrade Migration for cardboxShop (MySQL 8+)
-- Adds: product_variants (condition / sealed / no-shrink), pre-order & purchase limits,
-- language metadata, cart/order variant support, and restock_notifications.

USE `nba_db`;

-- 1. Extend `product` table with commercial TCG attributes
ALTER TABLE `product`
  ADD COLUMN `language` VARCHAR(30) DEFAULT '英文版' AFTER `card_condition`,
  ADD COLUMN `is_preorder` TINYINT(1) NOT NULL DEFAULT 0 AFTER `language`,
  ADD COLUMN `release_date` DATE DEFAULT NULL AFTER `is_preorder`,
  ADD COLUMN `max_qty_per_user` INT NOT NULL DEFAULT 0 COMMENT '0 = 無限購限制' AFTER `release_date`;

-- 2. Create `product_variants` table for card condition (NM/LP/PSA) or box seal status (Sealed/No Shrink)
CREATE TABLE IF NOT EXISTS `product_variants` (
  `variant_id` INT NOT NULL AUTO_INCREMENT,
  `product_id` INT NOT NULL,
  `variant_name` VARCHAR(100) NOT NULL COMMENT '例：全新有封膜 (Sealed)、拆膜無封膜 (No Shrink)、Near Mint (NM)',
  `condition_grade` VARCHAR(40) DEFAULT 'Sealed',
  `price` DECIMAL(10,2) NOT NULL,
  `stock` INT NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`variant_id`),
  KEY `idx_variant_product` (`product_id`),
  CONSTRAINT `fk_variant_product` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 3. Extend `cart_item` to support `variant_id` (0 = base product)
ALTER TABLE `cart_item`
  ADD COLUMN `variant_id` INT NOT NULL DEFAULT 0 AFTER `product_id`,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`member_id`, `product_id`, `variant_id`);

-- 4. Extend `order_item` to store `variant_id` and snapshot `variant_name`
ALTER TABLE `order_item`
  ADD COLUMN `variant_id` INT NOT NULL DEFAULT 0 AFTER `product_id`,
  ADD COLUMN `variant_name` VARCHAR(100) DEFAULT NULL AFTER `variant_id`;

-- 5. Create `restock_notifications` table for out-of-stock alert registration
CREATE TABLE IF NOT EXISTS `restock_notifications` (
  `notification_id` INT NOT NULL AUTO_INCREMENT,
  `member_id` INT NOT NULL,
  `product_id` INT NOT NULL,
  `variant_id` INT NOT NULL DEFAULT 0,
  `status` ENUM('等待通知','已通知','已取消') DEFAULT '等待通知',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notification_id`),
  UNIQUE KEY `uq_restock_member_item` (`member_id`, `product_id`, `variant_id`),
  KEY `idx_restock_product` (`product_id`),
  CONSTRAINT `fk_restock_member` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_restock_product` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 6. Sample commercial variants for demo products (idempotent inserts if empty)
INSERT INTO `product_variants` (`product_id`, `variant_name`, `condition_grade`, `price`, `stock`)
SELECT 9, '全新有封膜 (Sealed)', 'Sealed', 3500.00, 10
WHERE EXISTS (SELECT 1 FROM `product` WHERE `product_id` = 9)
  AND NOT EXISTS (SELECT 1 FROM `product_variants` WHERE `product_id` = 9);

INSERT INTO `product_variants` (`product_id`, `variant_name`, `condition_grade`, `price`, `stock`)
SELECT 9, '拆膜檢查無封膜 (No Shrink)', 'No Shrink', 3100.00, 5
WHERE EXISTS (SELECT 1 FROM `product` WHERE `product_id` = 9)
  AND NOT EXISTS (SELECT 1 FROM `product_variants` WHERE `product_id` = 9 AND `condition_grade` = 'No Shrink');
