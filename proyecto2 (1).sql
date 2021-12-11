-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 11-12-2021 a las 20:04:00
-- Versión del servidor: 10.4.21-MariaDB
-- Versión de PHP: 8.0.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `proyecto2`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `actualizar_precio_producto` (`n_cantidad` INT, `n_precio` DECIMAL(10,2), `codigo` INT)  BEGIN
	DECLARE nueva_existencia int;
    DECLARE nuevo_total decimal(10,2);
    DECLARE nuevo_precio decimal(10,2);
    
    DECLARE cant_actual int;
    DECLARE pre_actual decimal(10,2);
    
    DECLARE actual_existencia int;
    DECLARE actual_precio decimal(10,2);
    
    SELECT precio,existencia INTO actual_precio,actual_existencia FROM producto WHERE codproducto = codigo;
    SET nueva_existencia = actual_existencia + n_cantidad;
    SET nuevo_total = (actual_existencia * actual_precio) + (n_cantidad * n_precio);
    SET nuevo_precio = nuevo_total / nueva_existencia;
    
    UPDATE producto SET existencia = nueva_existencia, precio = nuevo_precio WHERE codproducto = codigo;
    
    SELECT nueva_existencia,nuevo_precio;
    
  END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `add_detalle_temp` (`codigo` INT, `cantidad` INT, `token_user` VARCHAR(50))  BEGIN
DECLARE precio_actual decimal (10,2);
SELECT precio INTO precio_actual FROM producto WHERE codproducto = codigo;
INSERT INTO detalle_temp(token_user,codproducto,cantidad,precio_venta) VALUES(token_user,codigo,cantidad,precio_actual);
SELECT tmp.correlativo,tmp.codproducto,p.descripcion,tmp.cantidad,tmp.precio_venta FROM detalle_temp tmp
INNER JOIN producto p
ON tmp.codproducto = p.codproducto
WHERE tmp.token_user = token_user;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `anular_factura` (`no_factura` INT)  BEGIN
     DECLARE existe_factura int ;
     DECLARE registros int ;
     DECLARE a int ;
     
      DECLARE cod_producto int ;
       DECLARE cant_producto int ;
        DECLARE existencia_actual int ;
         DECLARE nueva_existencia int ; 
     SET existe_factura = (SELECT COUNT(*) FROM factura WHERE nofactura = no_factura and estatus = 1);
     IF existe_factura > 0 THEN 
     
     CREATE TEMPORARY TABLE tbl_tmp
     (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
         cod_prod BIGINT ,
         cant_prod int) ;
         SET a = 1  ;
         SET registros = (SELECT COUNT(*) FROM detallefactura WHERE nofactura = no_factura);
         IF registros > 0 THEN 
INSERT INTO tbl_tmp (cod_prod,cant_prod) SELECT codproducto,cantidad FROM detallefactura WHERE nofactura = no_factura ;
         WHILE a <= registros DO 
         SELECT cod_prod,cant_prod INTO cod_producto,cant_producto FROM tbl_tmp WHERE id = a;
         SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = cod_producto;
         SET nueva_existencia = existencia_actual + cant_producto;
         UPDATE producto SET  existencia =  nueva_existencia WHERE codproducto = cod_producto;
         SET a = a +1;
         END WHILE ;
   
          UPDATE factura SET estatus = 2 WHERE nofactura = no_factura ;
          DROP TABLE  tbl_tmp ;
          SELECT * FROM factura WHERE nofactura = no_factura ;
         END IF;
         
     ELSE 
     SELECT 0 factura;
     END IF ;
     END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `dataDashboard` ()  BEGIN
    
    	DECLARE usuarios int;
        DECLARE clientes int;
        DECLARE proveedores int;
        DECLARE productos int;
        DECLARE ventas int;
        
        SELECT COUNT(*) INTO usuarios FROM usuario WHERE estatus != 10;
         SELECT COUNT(*) INTO clientes FROM cliente WHERE estatus != 10;
          SELECT COUNT(*) INTO proveedores FROM proveedor WHERE estatus != 10;
           SELECT COUNT(*) INTO productos FROM producto WHERE estatus != 10;
            SELECT COUNT(*) INTO ventas FROM factura WHERE fecha > CURDATE() AND estatus != 10;
            
            SELECT usuarios,clientes,proveedores,productos,ventas;
            
            
        END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `del_detalle_temp` (`id_detalle` INT, `token` VARCHAR(50))  BEGIN 
DELETE FROM detalle_temp WHERE correlativo = id_detalle;

SELECT tmp.correlativo,tmp.codproducto,p.descripcion,tmp.cantidad,tmp.precio_venta FROM detalle_temp tmp
INNER JOIN producto p
ON tmp.codproducto = p.codproducto
WHERE tmp.token_user = token;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_venta` (`cod_usuario` INT, `cod_cliente` INT, `token` VARCHAR(50))  BEGIN
        	DECLARE factura INT;
           
        	DECLARE registros INT;
            DECLARE total DECIMAL(10,2);
            
            DECLARE nueva_existencia int;
            DECLARE existencia_actual int;
            
            DECLARE tmp_cod_producto int;
            DECLARE tmp_cant_producto int;
            DECLARE a INT;
            SET a = 1;
            
            CREATE TEMPORARY TABLE tbl_tmp_tokenuser (
                	id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                	cod_prod BIGINT,
                	cant_prod int);
             SET registros = (SELECT COUNT(*) FROM detalle_temp WHERE token_user = token);
             
             IF registros > 0 THEN 
             	INSERT INTO tbl_tmp_tokenuser(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detalle_temp WHERE token_user = token;
                
                INSERT INTO factura(usuario,codcliente) VALUES(cod_usuario,cod_cliente);
                SET factura = LAST_INSERT_ID();
                
                INSERT INTO detallefactura(nofactura,codproducto,cantidad,precio_venta) SELECT (factura) as nofactura, codproducto,cantidad,precio_venta 				FROM detalle_temp WHERE token_user = token; 
                
                WHILE a <= registros DO
                	SELECT cod_prod,cant_prod INTO tmp_cod_producto,tmp_cant_producto FROM tbl_tmp_tokenuser WHERE id = a;
                    SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = tmp_cod_producto;
                    
                    SET nueva_existencia = existencia_actual - tmp_cant_producto;
                    UPDATE producto SET existencia = nueva_existencia WHERE codproducto = tmp_cod_producto;
                    
                    SET a=a+1;
                    
                
                END WHILE; 
                
                SET total = (SELECT SUM(cantidad * precio_venta) FROM detalle_temp WHERE token_user = token);
                UPDATE factura SET totalfactura = total WHERE nofactura = factura;
                DELETE FROM detalle_temp WHERE token_user = token;
                TRUNCATE TABLE tbl_tmp_tokenuser;
                SELECT * FROM factura WHERE nofactura = factura;
             
             ELSE
             SELECT 0;
             END IF;
             END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cliente`
--

CREATE TABLE `cliente` (
  `idcliente` int(11) NOT NULL,
  `nit` int(11) DEFAULT NULL,
  `nombre` varchar(80) DEFAULT NULL,
  `telefono` int(11) DEFAULT NULL,
  `direccion` text DEFAULT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `cliente`
--

INSERT INTO `cliente` (`idcliente`, `nit`, `nombre`, `telefono`, `direccion`, `dateadd`, `usuario_id`, `estatus`) VALUES
(1, 22, 'lina maria', 31222, '55', '2021-11-20 17:54:35', 1, 1),
(2, 0, 'ricardo', 23, '44', '2021-11-20 19:38:40', 1, 0),
(3, 99, 'ricardo alberto', 2147483647, '44', '2021-11-20 19:41:14', 1, 1),
(4, 44, 'ricardo alberto', 433335, '545', '2021-11-20 22:32:49', 1, 0),
(5, 20, 'michael rodriguez', 2147483647, '66N45', '2021-11-22 14:35:11', 1, 1),
(6, 3, 'Santi', 233, '323', '2021-11-30 22:00:00', 1, 1),
(7, 3435, 'carlos', 32, '5565', '2021-11-30 22:39:07', 1, 0),
(10, 33, 'marithea', 12132, '2323', '2021-12-01 01:56:17', 1, 1),
(11, 5555, 'maria', 454643, 'sur', '2021-12-01 02:09:15', 1, 1),
(12, 9, 'Alfonsito Gamez', 2147483647, 'juan rey', '2021-12-04 01:26:43', 1, 1),
(13, 21, 'Michael Rodríguez', 2147483647, 'dindalito', '2021-12-04 01:32:20', 1, 1),
(14, 55, 'Genrry', 45456, 'chile', '2021-12-06 02:33:33', 1, 1),
(15, 344, 'mkiwozz', 23342, 'argentina', '2021-12-06 02:53:34', 1, 1),
(16, 78, 'jhon cadena', 5, 'porvenir', '2021-12-08 13:17:19', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuracion`
--

CREATE TABLE `configuracion` (
  `id` bigint(20) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `razon_social` varchar(100) NOT NULL,
  `telefono` bigint(20) NOT NULL,
  `email` varchar(200) NOT NULL,
  `direccion` text NOT NULL,
  `iva` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Volcado de datos para la tabla `configuracion`
--

INSERT INTO `configuracion` (`id`, `nit`, `nombre`, `razon_social`, `telefono`, `email`, `direccion`, `iva`) VALUES
(1, '405954', 'bodeguita Cor', 'Frutas Exportadas', 3146689082, 'bodeguita82@gmail.com', 'bogota-82-58', '5.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallefactura`
--

CREATE TABLE `detallefactura` (
  `correlativo` bigint(11) NOT NULL,
  `nofactura` bigint(11) DEFAULT NULL,
  `codproducto` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `detallefactura`
--

INSERT INTO `detallefactura` (`correlativo`, `nofactura`, `codproducto`, `cantidad`, `precio_venta`) VALUES
(1, 1, 45, 1, '3000.00'),
(2, 1, 33, 7, '500.00'),
(3, 1, 34, 2, '500.00'),
(4, 1, 37, 1, '500.00'),
(5, 1, 38, 4, '293.75'),
(6, 1, 47, 2, '200.00'),
(8, 2, 33, 1, '500.00'),
(9, 2, 44, 25, '600.00'),
(11, 3, 45, 1, '3000.00'),
(12, 3, 40, 5, '3200.00'),
(13, 4, 33, 1, '500.00'),
(14, 5, 44, 2, '600.00'),
(15, 5, 45, 1, '3000.00'),
(16, 5, 50, 5, '1000.00'),
(17, 6, 34, 2, '500.00'),
(18, 6, 37, 1, '500.00'),
(20, 7, 49, 1, '500.00'),
(21, 8, 44, 1, '600.00'),
(22, 9, 46, 1, '500.00'),
(23, 10, 41, 6, '253.33'),
(24, 11, 46, 2, '500.00'),
(25, 12, 46, 2, '500.00'),
(26, 13, 48, 1, '350.00'),
(27, 14, 50, 2, '1000.00'),
(28, 15, 34, 1, '500.00'),
(29, 16, 44, 1, '600.00'),
(30, 17, 50, 1, '1000.00'),
(31, 18, 48, 1, '350.00'),
(32, 19, 48, 1, '350.00'),
(33, 20, 49, 1, '500.00'),
(34, 21, 50, 1, '1000.00'),
(35, 22, 48, 1, '350.00'),
(36, 23, 48, 1, '350.00'),
(37, 24, 45, 1, '3000.00'),
(38, 25, 46, 1, '500.00'),
(39, 26, 51, 1, '500.00'),
(40, 27, 51, 1, '500.00'),
(41, 28, 51, 4, '500.00'),
(42, 29, 51, 10, '500.00'),
(43, 30, 46, 2, '500.00'),
(44, 30, 43, 5, '3400.00'),
(45, 31, 51, 1, '500.00'),
(46, 32, 45, 5, '3000.00'),
(47, 33, 45, 3, '600.00'),
(48, 34, 43, 5, '3400.00'),
(49, 35, 41, 6, '253.33'),
(50, 36, 43, 5, '3400.00'),
(51, 37, 53, 5, '200.00'),
(52, 38, 53, 1, '200.00'),
(53, 39, 53, 1, '200.00'),
(54, 40, 53, 1, '200.00'),
(55, 41, 53, 1, '200.00'),
(56, 41, 42, 2, '500.00'),
(57, 42, 53, 4, '200.00'),
(58, 43, 43, 10, '3400.00'),
(59, 43, 53, 6, '200.00'),
(60, 44, 43, 4, '3400.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_temp`
--

CREATE TABLE `detalle_temp` (
  `correlativo` int(11) NOT NULL,
  `token_user` varchar(50) NOT NULL,
  `codproducto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entradas`
--

CREATE TABLE `entradas` (
  `correlativo` int(11) NOT NULL,
  `codproducto` int(11) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `cantidad` int(11) NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `usuario_id` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `entradas`
--

INSERT INTO `entradas` (`correlativo`, `codproducto`, `fecha`, `cantidad`, `precio`, `usuario_id`) VALUES
(32, 32, '2021-11-25 10:55:16', 5, '300.00', 1),
(33, 33, '2021-11-25 10:56:59', 8, '500.00', 1),
(34, 34, '2021-11-25 10:59:54', 6, '500.00', 1),
(35, 35, '2021-11-25 11:00:09', 4, '200.00', 1),
(36, 36, '2021-11-25 11:07:03', 4, '200.00', 1),
(37, 37, '2021-11-25 11:48:03', 2, '500.00', 1),
(38, 38, '2021-11-25 11:48:40', 5, '500.00', 1),
(39, 39, '2021-11-25 11:51:01', 6, '300.00', 1),
(40, 40, '2021-11-25 11:51:31', 6, '5000.00', 1),
(41, 41, '2021-11-25 11:52:02', 4, '400.00', 1),
(42, 40, '2021-11-26 23:30:15', 4, '500.00', 1),
(43, 41, '2021-11-27 00:10:55', 6, '200.00', 1),
(44, 38, '2021-11-27 00:12:44', 5, '200.00', 1),
(45, 38, '2021-11-27 00:13:28', 6, '200.00', 1),
(46, 39, '2021-11-27 00:14:20', 6, '200.00', 1),
(47, 41, '2021-11-27 00:47:03', 5, '200.00', 1),
(48, 42, '2021-11-27 01:00:28', 5, '500.00', 1),
(49, 43, '2021-11-27 02:38:03', 6, '300.00', 1),
(50, 43, '2021-11-27 02:38:20', 4, '200.00', 1),
(51, 43, '2021-11-27 19:10:51', 5, '200.00', 1),
(52, 44, '2021-11-29 17:55:35', 30, '600.00', 1),
(53, 45, '2021-11-29 17:57:59', 5, '3000.00', 1),
(54, 46, '2021-11-29 17:58:38', 6, '500.00', 1),
(55, 46, '2021-11-29 17:59:15', 4, '500.00', 1),
(56, 47, '2021-11-29 18:00:04', 5, '200.00', 1),
(57, 48, '2021-11-29 18:00:25', 4, '200.00', 1),
(58, 48, '2021-11-29 21:38:43', 4, '500.00', 1),
(59, 49, '2021-11-29 21:41:14', 4, '500.00', 1),
(60, 50, '2021-11-30 22:04:26', 5, '1000.00', 1),
(61, 50, '2021-11-30 22:06:35', 5, '1000.00', 1),
(62, 51, '2021-12-03 22:54:11', 50, '500.00', 1),
(63, 51, '2021-12-06 01:52:38', 36, '500.00', 1),
(64, 51, '2021-12-06 01:53:30', 69, '600.00', 1),
(65, 51, '2021-12-06 01:53:43', 138, '650.00', 1),
(66, 51, '2021-12-06 01:55:22', 267, '400.00', 1),
(67, 50, '2021-12-06 01:55:46', 5, '1000.00', 1),
(68, 45, '2021-12-06 02:32:24', 5, '3000.00', 1),
(69, 45, '2021-12-06 02:48:57', 6, '200.00', 1),
(70, 52, '2021-12-06 02:54:54', 8, '200.00', 1),
(71, 52, '2021-12-06 03:04:15', 6, '200.00', 1),
(72, 44, '2021-12-06 19:47:27', 10, '600.00', 1),
(73, 53, '2021-12-08 13:14:37', 4, '200.00', 1),
(74, 53, '2021-12-08 13:15:10', 6, '200.00', 1),
(75, 42, '2021-12-10 10:38:58', 4, '500.00', 1),
(76, 53, '2021-12-10 11:08:04', 4, '200.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `factura`
--

CREATE TABLE `factura` (
  `nofactura` bigint(11) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario` int(11) DEFAULT NULL,
  `codcliente` int(11) DEFAULT NULL,
  `totalfactura` decimal(10,2) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `factura`
--

INSERT INTO `factura` (`nofactura`, `fecha`, `usuario`, `codcliente`, `totalfactura`, `estatus`) VALUES
(1, '2021-12-02 22:54:02', 1, 6, '9575.00', 2),
(2, '2021-12-02 22:58:55', 1, 1, '15500.00', 2),
(3, '2021-12-03 00:56:34', 1, 10, '19000.00', 1),
(4, '2021-12-03 01:47:40', 1, 1, '500.00', 1),
(5, '2021-12-03 02:25:08', 1, 10, '9200.00', 1),
(6, '2021-12-03 02:29:03', 1, 6, '1500.00', 1),
(7, '2021-12-03 02:52:37', 1, 10, '500.00', 1),
(8, '2021-12-03 02:55:09', 1, 10, '600.00', 1),
(9, '2021-12-03 03:18:41', 1, 11, '500.00', 1),
(10, '2021-12-03 20:13:42', 1, 11, '1519.98', 1),
(11, '2021-12-03 20:47:15', 1, 3, '1000.00', 2),
(12, '2021-12-03 21:02:21', 1, 10, '1000.00', 1),
(13, '2021-12-03 21:12:29', 1, 3, '350.00', 1),
(14, '2021-12-03 21:14:32', 1, 10, '2000.00', 2),
(15, '2021-12-03 21:17:04', 1, 11, '500.00', 2),
(16, '2021-12-03 21:19:32', 1, 11, '600.00', 1),
(17, '2021-12-03 21:20:22', 1, 3, '1000.00', 1),
(18, '2021-12-03 21:22:38', 1, 10, '350.00', 1),
(19, '2021-12-03 21:23:41', 1, 7, '350.00', 1),
(20, '2021-12-03 21:45:39', 1, 10, '500.00', 1),
(21, '2021-12-03 22:16:39', 1, 11, '1000.00', 1),
(22, '2021-12-03 22:22:23', 1, 6, '350.00', 1),
(23, '2021-12-03 22:23:44', 1, 11, '350.00', 1),
(24, '2021-12-03 22:25:24', 1, 6, '3000.00', 2),
(25, '2021-12-03 22:29:32', 1, 11, '500.00', 1),
(26, '2021-12-03 23:15:39', 1, 11, '500.00', 2),
(27, '2021-12-03 23:33:28', 1, 10, '500.00', 1),
(28, '2021-12-04 01:20:55', 1, 10, '2000.00', 2),
(29, '2021-12-04 01:27:00', 1, 12, '5000.00', 1),
(30, '2021-12-04 01:33:37', 1, 13, '18000.00', 2),
(31, '2021-12-04 22:47:44', 1, 13, '500.00', 2),
(32, '2021-12-06 02:34:14', 1, 14, '15000.00', 2),
(33, '2021-12-06 22:33:48', 1, 1, '1800.00', 2),
(34, '2021-12-07 02:31:25', 1, 10, '17000.00', 2),
(35, '2021-12-07 03:06:11', 1, 11, '1519.98', 2),
(36, '2021-12-08 13:17:48', 1, 16, '17000.00', 2),
(37, '2021-12-08 19:24:47', 1, 10, '1000.00', 1),
(38, '2021-12-08 20:03:51', 1, 11, '200.00', 2),
(39, '2021-12-08 20:04:58', 1, 13, '200.00', 2),
(40, '2021-12-09 17:25:51', 1, 12, '200.00', 1),
(41, '2021-12-09 18:08:33', 1, 13, '1200.00', 1),
(42, '2021-12-10 11:08:42', 1, 10, '800.00', 2),
(43, '2021-12-10 19:04:19', 1, 13, '35200.00', 1),
(44, '2021-12-11 12:17:03', 1, 13, '13600.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto`
--

CREATE TABLE `producto` (
  `codproducto` int(11) NOT NULL,
  `descripcion` varchar(100) DEFAULT NULL,
  `proveedor` int(11) DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `existencia` int(11) DEFAULT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1,
  `foto` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `producto`
--

INSERT INTO `producto` (`codproducto`, `descripcion`, `proveedor`, `precio`, `existencia`, `dateadd`, `usuario_id`, `estatus`, `foto`) VALUES
(32, 'fresa', 7, '300.00', 5, '2021-11-25 10:55:16', 1, 1, 'img_producto.jpg'),
(33, 'manzanas', 7, '500.00', 7, '2021-11-25 10:56:59', 1, 0, 'img_14ae601ca40048dc36095c14d58fe1a5.jpg '),
(34, 'peritas', 17, '500.00', 4, '2021-11-25 10:59:54', 1, 1, 'img_f7d8c0a00636c222af0008e061c2e333.jpg '),
(35, 'pera', 7, '200.00', 4, '2021-11-25 11:00:09', 1, 0, 'img_producto.jpg '),
(36, 'pera', 7, '200.00', 4, '2021-11-25 11:07:03', 1, 0, 'img_producto.jpg '),
(37, 'uvas', 16, '500.00', 1, '2021-11-25 11:48:03', 1, 0, 'img_dd6bfe0c0716e8dc314e6ce96161a86f.jpg '),
(38, 'manzanas', 17, '293.75', 16, '2021-11-25 11:48:40', 1, 1, 'img_producto.jpg'),
(39, 'moras', 15, '250.00', 12, '2021-11-25 11:51:01', 1, 1, 'img_859a5ae569f076b24502563ee15dca19.jpg'),
(40, 'patilla', 7, '3200.00', 5, '2021-11-25 11:51:31', 1, 1, 'img_bc15a602ef0d50e39022879f9eeef980.jpg '),
(41, 'uvas verdes', 7, '253.33', 9, '2021-11-25 11:52:02', 1, 1, 'img_producto.jpg'),
(42, 'manzanas', 15, '500.00', 7, '2021-11-27 01:00:28', 1, 1, 'img_1c33c9dba6285ca79eedf484fbdf3b00.jpg'),
(43, 'limones', 17, '3400.00', 1, '2021-11-27 02:38:03', 1, 1, 'img_60a7f909e5b0ef178943df220f449ff0.jpg'),
(44, 'mangos', 16, '600.00', 36, '2021-11-29 17:55:35', 1, 0, 'img_ead4d65def6d47bdda550563e9b06716.jpg '),
(45, 'piñas', 13, '600.00', 14, '2021-11-29 17:57:59', 1, 0, 'img_da366ed585d929e6620c39a00663beaa.jpg '),
(46, 'manzanas', 1, '500.00', 6, '2021-11-29 17:58:38', 1, 0, 'img_c4f13055a855480e394f014304e144c7.jpg '),
(47, 'fresas', 7, '200.00', 5, '2021-11-29 18:00:04', 1, 0, 'img_5bc35d613a57b425922aa6437dbaae61.jpg '),
(48, 'limones', 10, '350.00', 3, '2021-11-29 18:00:25', 1, 0, 'img_4db70fb1612f502dc18077972d01a981.jpg '),
(49, 'manzanas', 13, '500.00', 2, '2021-11-29 21:41:14', 1, 0, 'img_producto.jpg'),
(50, 'manzanas', 18, '1000.00', 8, '2021-11-30 22:04:26', 1, 0, 'img_producto.jpg'),
(51, 'peras', 7, '501.66', 549, '2021-12-03 22:54:11', 1, 0, 'img_811824295bddca8078faeba215c990cd.jpg'),
(52, 'limones', 7, '200.00', 14, '2021-12-06 02:54:54', 1, 0, 'img_3ef963deb3a02b27eb3b7fa980d686b5.jpg '),
(53, 'fresas', 15, '200.00', 1, '2021-12-08 13:14:37', 1, 1, 'img_a145673a5d64a531ecadef068f7e3674.jpg');

--
-- Disparadores `producto`
--
DELIMITER $$
CREATE TRIGGER `entradas_A_I` AFTER INSERT ON `producto` FOR EACH ROW BEGIN
    	INSERT INTO entradas(codproducto,cantidad,precio,usuario_id)
        VALUES(new.codproducto,new.existencia,new.precio,new.usuario_id);
    END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedor`
--

CREATE TABLE `proveedor` (
  `codproveedor` int(11) NOT NULL,
  `proveedor` varchar(100) DEFAULT NULL,
  `contacto` varchar(100) DEFAULT NULL,
  `telefono` bigint(11) DEFAULT NULL,
  `direccion` text DEFAULT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `proveedor`
--

INSERT INTO `proveedor` (`codproveedor`, `proveedor`, `contacto`, `telefono`, `direccion`, `dateadd`, `usuario_id`, `estatus`) VALUES
(1, 'BIC', 'Claudia Rosales', 789877889, 'Avenida las Americas', '2021-11-23 00:57:20', 1, 1),
(2, 'CASIO', 'Jorge Herrera', 565656565656, 'Calzada Las Flores', '2021-11-23 00:57:20', 1, 0),
(3, 'Omega', 'Julio Estrada', 982877489, 'Avenida Elena Zona 4, Guatemala', '2021-11-23 00:57:20', 1, 0),
(4, 'Dell Compani', 'Roberto Estrada', 2147483647, '82', '2021-11-23 00:57:20', 1, 0),
(5, 'Olimpia S.A', 'Elena Franco Morales', 564535676, '55 con caracas', '2021-11-23 00:57:20', 1, 1),
(6, 'Oster', 'Fernando Guerra', 78987678, 'Calzada La Paz, Guatemala', '2021-11-23 00:57:20', 1, 1),
(7, 'ACELTECSA S.A', 'Ruben PÃƒÂ©rez', 789879889, 'Colonia las Victorias', '2021-11-23 00:57:20', 1, 1),
(8, 'Sony', 'Julieta Contreras', 89476787, 'Antigua Guatemala', '2021-11-23 00:57:20', 1, 0),
(9, 'VAIO', 'Felix Arnoldo Rojas', 476378276, 'Avenida las Americas Zona 13', '2021-11-23 00:57:20', 1, 1),
(10, 'SUMAR', 'Oscar Maldonado', 788376787, 'Colonia San Jose, Zona 5 Guatemala', '2021-11-23 00:57:20', 1, 1),
(11, 'HP', 'Angel Cardona', 2147483647, '5ta. calle zona 4 Guatemala', '2021-11-23 00:57:20', 1, 1),
(12, 'importadora rosales', 'cristian castro', 22343876, '33', '2021-11-23 01:34:32', 1, 1),
(13, 'manzanitas', 'spaick rocha', 22222, '57', '2021-11-23 01:36:14', 19, 1),
(14, 'importadora rosales', 'cristian castro', 22343876, '33', '2021-11-23 01:53:59', 1, 1),
(15, 'manzanitas', 'spaick rocha', 22222, '57', '2021-11-23 02:43:12', 19, 1),
(16, 'peritas doña manuela', 'eugenia robles tabares', 32343444, '443sur', '2021-11-23 02:44:16', 1, 1),
(17, 'PERITAS BEBES', 'alfonso gamez', 2324324, '565', '2021-11-24 02:06:41', 1, 0),
(18, 'azucar manuelita', 'manuelita', 34352, '43sur', '2021-11-30 22:02:07', 1, 1),
(19, 'uvitas16', 'hugo gallego', 346343, 'bogota', '2021-12-06 02:54:13', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol`
--

CREATE TABLE `rol` (
  `idrol` int(11) NOT NULL,
  `rol` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `rol`
--

INSERT INTO `rol` (`idrol`, `rol`) VALUES
(1, 'administrador'),
(2, 'supervisor'),
(3, 'vendedor');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

CREATE TABLE `usuario` (
  `idusuario` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `correo` varchar(100) DEFAULT NULL,
  `usuario` varchar(15) DEFAULT NULL,
  `clave` varchar(100) DEFAULT NULL,
  `rol` int(11) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`idusuario`, `nombre`, `correo`, `usuario`, `clave`, `rol`, `estatus`) VALUES
(1, 'Zharick ', 'znrocha@misena.edu.co', 'admin', 'fcea920f7412b5da7be0cf42b8c93759', 1, 1),
(2, 'Zharick ', 'zharicknicole21@gmail.com', 'vendedora', '123', 3, 1),
(3, 'sharyc', 'sharyc@gmail.com', 'monitora', 'd41d8cd98f00b204e9800998ecf8427e', 3, 0),
(4, 'rodolfo', 'rodi@gmail.com', 'dxcsac', 'a412957cefda4b198420bf4de90f1c25', 3, 0),
(5, 'fabian', 'fabi@gmail.com', 'fabi', 'd41d8cd98f00b204e9800998ecf8427e', 3, 0),
(6, 'dania', 'dasa@gmail.com', 'dani dani', 'd41d8cd98f00b204e9800998ecf8427e', 1, 0),
(8, 'macta llega ', 'mactadaleduro@gmail.com', 'mactica', '202cb962ac59075b964b07152d234b70', 2, 1),
(9, 'Santi', 'moana@gmail.com', 'moanita', 'd41d8cd98f00b204e9800998ecf8427e', 3, 1),
(10, 'anthony david', 'david@gmail.com', 'david', '202cb962ac59075b964b07152d234b70', 2, 0),
(11, 'maria luz', 'maria@gmail.com', 'mari', '202cb962ac59075b964b07152d234b70', 1, 1),
(12, 'mariana camacho', 'mariana@gmail.com', 'mariana', '202cb962ac59075b964b07152d234b70', 2, 1),
(13, 'alfonso gamez', 'alfonsito@gmail.com', 'alfonsito', '202cb962ac59075b964b07152d234b70', 3, 1),
(14, 'lina rocha', 'lina04@gmail.com', 'lina', '202cb962ac59075b964b07152d234b70', 1, 1),
(15, 'juana ', 'juanita@gmail.com', 'juanita', '202cb962ac59075b964b07152d234b70', 3, 1),
(16, 'milena rocha', 'milena@gmail.com', 'milena', '202cb962ac59075b964b07152d234b70', 2, 1),
(17, 'yeinz', 'yeinz@gmail.com', 'yeinz', '202cb962ac59075b964b07152d234b70', 1, 1),
(18, 'levi ackerman', 'levi@gmail.com', 'levi mata titan', '202cb962ac59075b964b07152d234b70', 1, 1),
(19, 'naruto uzumaki', 'naruto@gmail.com', 'naruto', '202cb962ac59075b964b07152d234b70', 2, 1),
(20, 'sakura ', 'sakura@gmail.com', 'sakura', '202cb962ac59075b964b07152d234b70', 3, 1),
(21, 'sasuke uchiha', 'uchiha@gmail.com', 'sasuke', '202cb962ac59075b964b07152d234b70', 2, 1),
(22, 'ino yamanaka', 'ino@gmail.com', 'ino', '202cb962ac59075b964b07152d234b70', 1, 1),
(23, 'hinata ', 'hinata@gmail.com', 'hinata', '202cb962ac59075b964b07152d234b70', 2, 1),
(24, 'itachi uchiha', 'itachi@gmail.com', 'itachi', '202cb962ac59075b964b07152d234b70', 2, 1),
(25, 'obito', 'obito@gmail.com', 'obi', '202cb962ac59075b964b07152d234b70', 3, 1),
(26, 'El Santi', 'santi@misena.edu.co', 'Santiago', '202cb962ac59075b964b07152d234b70', 1, 1),
(27, 'Diego Bello', 'Diego@gmail.com', 'Diego', '202cb962ac59075b964b07152d234b70', 2, 1),
(28, 'mike', 'miike@gmail.com', 'miki', '202cb962ac59075b964b07152d234b70', 1, 1);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD PRIMARY KEY (`idcliente`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `configuracion`
--
ALTER TABLE `configuracion`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `codproducto` (`codproducto`),
  ADD KEY `nofactura` (`nofactura`);

--
-- Indices de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `nofactura` (`token_user`),
  ADD KEY `codproducto` (`codproducto`);

--
-- Indices de la tabla `entradas`
--
ALTER TABLE `entradas`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `codproducto` (`codproducto`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `factura`
--
ALTER TABLE `factura`
  ADD PRIMARY KEY (`nofactura`),
  ADD KEY `usuario` (`usuario`),
  ADD KEY `codcliente` (`codcliente`);

--
-- Indices de la tabla `producto`
--
ALTER TABLE `producto`
  ADD PRIMARY KEY (`codproducto`),
  ADD KEY `proveedor` (`proveedor`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  ADD PRIMARY KEY (`codproveedor`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `rol`
--
ALTER TABLE `rol`
  ADD PRIMARY KEY (`idrol`);

--
-- Indices de la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`idusuario`),
  ADD KEY `rol` (`rol`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `cliente`
--
ALTER TABLE `cliente`
  MODIFY `idcliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de la tabla `configuracion`
--
ALTER TABLE `configuracion`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  MODIFY `correlativo` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=61;

--
-- AUTO_INCREMENT de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=71;

--
-- AUTO_INCREMENT de la tabla `entradas`
--
ALTER TABLE `entradas`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=77;

--
-- AUTO_INCREMENT de la tabla `factura`
--
ALTER TABLE `factura`
  MODIFY `nofactura` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=45;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `codproducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  MODIFY `codproveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT de la tabla `rol`
--
ALTER TABLE `rol`
  MODIFY `idrol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `idusuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD CONSTRAINT `cliente_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  ADD CONSTRAINT `detallefactura_ibfk_1` FOREIGN KEY (`nofactura`) REFERENCES `factura` (`nofactura`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detallefactura_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  ADD CONSTRAINT `detalle_temp_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `entradas`
--
ALTER TABLE `entradas`
  ADD CONSTRAINT `entradas_ibfk_1` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `factura`
--
ALTER TABLE `factura`
  ADD CONSTRAINT `factura_ibfk_1` FOREIGN KEY (`usuario`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `factura_ibfk_2` FOREIGN KEY (`codcliente`) REFERENCES `cliente` (`idcliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `producto`
--
ALTER TABLE `producto`
  ADD CONSTRAINT `producto_ibfk_1` FOREIGN KEY (`proveedor`) REFERENCES `proveedor` (`codproveedor`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `producto_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `proveedor`
--
ALTER TABLE `proveedor`
  ADD CONSTRAINT `proveedor_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD CONSTRAINT `usuario_ibfk_1` FOREIGN KEY (`rol`) REFERENCES `rol` (`idrol`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
