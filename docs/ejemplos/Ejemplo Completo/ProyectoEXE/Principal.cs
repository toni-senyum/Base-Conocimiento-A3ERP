using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using a3ERPActiveXNET;

namespace a3ERPActiveXPlantillas
{
    public partial class Principal : Form
    {
        Log log = null;
        Conexion cn = null;
        Enlace enlace = null;

        public Principal()
        {
            InitializeComponent();

            this.Load += new EventHandler(Principal_Load);
            this.FormClosed += new FormClosedEventHandler(Principal_FormClosed);
        }

        void Principal_FormClosed(object sender, FormClosedEventArgs e)
        {
            if (enlace != null)
            {
                enlace.Acabar();
                log.Escribir("Enlace cerrado");
            }

            cn.CerrarConexion();
            log.Escribir("Conexión liberada");

            enlace = null;
            cn = null;
            log = null;
        }

        void Principal_Load(object sender, EventArgs e)
        {
            log = new Log(lbLogVisual);
            cn = new Conexion();

            log.Escribir("Log registrado");
            log.Escribir("Conexión registrada");

            if (String.IsNullOrWhiteSpace(ParametrosMenu.Empresa))
                log.Escribir("El programa no se ha invocado desde el menu");
            else
            {
                log.Escribir("El programa SE HA INVOCADO desde el menu");
                log.Escribir("Datos:");
                log.Escribir(String.Format("Empresa: {0}", ParametrosMenu.Empresa));
                log.Escribir(String.Format("Usuario: {0}", ParametrosMenu.Usuario));
                log.Escribir(String.Format("Password: {0}", ParametrosMenu.Password));
            }
        }

        private void CheckEnalce()
        {
            if (enlace == null)
                return;

            if (enlace.bError)
                log.Escribir(enlace.sMensaje);
        }

        private void btnEnlace_Click(object sender, EventArgs e)
        {
            enlace = new Enlace();
            enlace.RaiseOnException = true;

            enlace.LoginUsuario("sa", "A3erp4848");
            enlace.Iniciar("X_DESARROLLOS");

            if (enlace.Estado == EstadoEnlace.estACTIVO)
                log.Escribir("empresa conectada X_DESARROLLOS");


            string conexioncompleta = Conexion.ConexionSql.GenerarConexion(enlace.Conexion, enlace.Usuario, "A3erp4848");
            Conexion.ConexionSql.AbrirConexion(conexioncompleta);

            log.Escribir(String.Format("Conexión empresa {0}", conexioncompleta));
        }

        private void btnMestro_Click(object sender, EventArgs e)
        {
            Maestro maestro = new Maestro();

            try
            {
                try
                {
                    maestro.Iniciar("DIRENT");
                    maestro.Nuevo();
                    maestro.AsString["CodCli"] = "1";
                    maestro.AsString["NomEnt"] = "Alta ejemplo";
                    maestro.Guarda(true);
                    CheckEnalce();
                    log.Escribir("Dirección de entrega creada");

                    if (maestro.Buscar(new object[] { "1", "2" }))
                    {
                        maestro.Edita();
                        maestro.AsString["NomEnt"] = "Modificado ejemplo1";
                        maestro.Guarda(true);
                        CheckEnalce();
                        log.Escribir("Dirección de entrega modificada");
                    }

                }
                finally
                {
                    maestro.Acabar();
                    CheckEnalce();
                }
            }
            catch (Exception ex)
            {
                log.Escribir(String.Format("Error: {0}", ex.Message));
            }

        }

        private void button1_Click(object sender, EventArgs e)
        {
            Maestro articulo = new Maestro();
            articulo.Iniciar("Articulos");
            articulo.Nuevo();
            articulo.AsString["CODART"] = "X110";
            articulo.AsVariant["DESCART"] = "descripción del X110";
            articulo.AsString["CODMON"] = "";
            articulo.AsVariant["TIPIVA"] = null;

            articulo.Guarda(true);
            CheckEnalce();
            articulo.Acabar();

            log.Escribir("Artículo guardado");

        }

        private void btnAlbaran_Click(object sender, EventArgs e)
        {
            decimal iddocumento = 0;
            int idlinea = 0;
            bool ok = false;

            Albaran documento = new Albaran();
            try
            {
                try
                {
                    documento.Iniciar();

                    documento.OmitirMensajes = true;
                    documento.Nuevo(String.Format("{0:dd/MM/yyyy}", DateTime.Now), "1", false);
                    documento.AsStringCab["CODTRA"] = "1";
                    documento.AsStringCab["SERIE"] = "2018";

                    // linea artículo lotes sin carga automática del detalle
                    documento.NuevaLinea();
                    documento.AsStringLin["CODART"] = "50";
                    documento.AsFloatLin["UNIDADESSTOCK"] = 1;
                    documento.AsFloatLin["UNIDADES"] = 1;
                    documento.AsFloatLin["PRCMONEDA"] = 100;

                    //Añadir detalle versión anterior a la 11
                    //documento.AnadirDetalle(1, string.Empty, "L11", string.Empty, "30/12/1899");

                    LineaDetalleParametros lineadetalle = new LineaDetalleParametros()
                    {
                        Lote = "L11",
                        UnidadesStock = 1,
                        UnidadesPrecio = 1
                    };

                    ((ILineaDetalle)documento).AnadirDetalle(lineadetalle);
                    documento.AnadirLinea();
                    CheckEnalce();

                    // linea artículo normal
                    documento.NuevaLineaArt("1", 10);
                    documento.AnadirLinea();
                    CheckEnalce();


                    object[] lineas = ((ILineasDocumento)documento).ObtenerLineas();
                    for (int l = 1; (l <= (int)lineas[0]); l++)
                    {
                        object[] item = (lineas[l] as object[]);
                        for (int c = 1; (c <= (int)item[0]); c++)
                        {
                            object[] item2 = (item[c] as object[]);

                            if ((item2[0].ToString().ToUpper() == "CODART") & (item2[1].ToString().ToUpper().Trim() == "50"))
                            {
                                ok = true;
                            }

                            if ((ok) & (item2[0].ToString().ToUpper() == "NUMLINALB"))
                            {
                                ok = false;
                                log.Escribir(Convert.ToString(item2[1]));
                                idlinea = (int)item2[1];
                            }
                        }
                    }

                    documento.EditarLinea(idlinea);

                    object[] lineasdet = ((ILineasDocumento)documento).ObtenerDetallesLinea();

                    for (int l = 1; (l <= (int)lineasdet[0]); l++)
                    {
                        object[] item = (lineasdet[l] as object[]);
                        for (int c = 1; (c <= (int)item[0]); c++)
                        {
                            object[] item2 = (item[c] as object[]);

                            if (item2[0].ToString().ToUpper() == "IDLIN")
                            {
                                log.Escribir(Convert.ToString(item2[1]));
                                idlinea = Convert.ToInt32(item2[1]);
                            }
                        }
                    }


                    lineadetalle.Linea = idlinea;
                    lineadetalle.Lote = "L12";
                    ((ILineaDetalle)documento).CambiarDetalle(lineadetalle);
                    documento.AnadirLinea();
                    CheckEnalce();

                    documento.NuevaLineaArt("37", 10);
                    documento.NuevoComponente();
                    documento.AsStringComp["CODART"] = "34";
                    documento.AsFloatComp["UNIDADESSTOCK"] = 5;
                    documento.AsFloatComp["UNIDADES"] = 5;
                    documento.AsFloatComp["PRCMONEDA"] = 50;
                    documento.AnadirComponente();
                    documento.NuevoComponente();
                    documento.AsStringComp["CODART"] = "35";
                    documento.AsFloatComp["UNIDADESSTOCK"] = 4;
                    documento.AsFloatComp["UNIDADES"] = 4;
                    documento.AsFloatComp["PRCMONEDA"] = 40;
                    documento.AnadirComponente();
                    documento.AnadirLinea();

                    iddocumento = documento.Anade();
                    CheckEnalce();

                    log.Escribir("Albarán guardado");
                }
                catch (Exception ex)
                {
                    log.Escribir("Error al grabar el albarán: " + ex.Message);
                    documento.Cancela();
                    CheckEnalce();
                }

            }
            finally
            {
                documento.Acabar();
                CheckEnalce();
            }
        }

        private void btnOpcion_Click(object sender, EventArgs e)
        {
            Opcion op = new Opcion();
            try
            {
                op.Iniciar();
                op.IdOpcion = "manClientes";
                op.AnadirParametro("Accion", "Edicion");
                op.AnadirParametro("Codigo", "       1");
                op.Ejecutar();
            }
            finally
            {
                op.Acabar();
            }
        }

        private void btnListado_Click(object sender, EventArgs e)
        {
            Listado lis = new Listado();
            try
            {
                lis.Iniciar();
                lis.IdListado = "LSTIMPRALBV";
                //lis.Destino = DestinoListado.destPantalla;
                lis.Destino = DestinoListado.destPDF;
                lis.Fichero = @"c:\logs\prueba.pdf";
                lis.AnadirParametro("Identificador", "1150");
                lis.Imprimir();
            }
            finally
            {
                lis.Acabar();
            }
        }

        private void btnCartera_Click(object sender, EventArgs e)
        {
            decimal resultado = 0;
            Cartera a3Cartera = null;

            try
            {
                a3Cartera = new Cartera();
                a3Cartera.Iniciar();
                a3Cartera.NuevoNax(String.Format("{0:dd/MM/yyyy}", DateTime.Now), "1", "EURO", "1", "", "", "", false);
                a3Cartera.AsString["CODBAN"] = "2";
                a3Cartera.AsVariant["DOCPAG"] = "E";

                a3Cartera.NuevoVen(String.Format("{0:dd/MM/yyyy}", DateTime.Now), 100);
                a3Cartera.AnadirVen();
                CheckEnalce();
                resultado = a3Cartera.Anade();
                CheckEnalce();
                log.Escribir("Efecto creado con numcartera:" + resultado.ToString());

                if (a3Cartera.PuedeModificarse(resultado))
                {
                    CheckEnalce();
                    a3Cartera.Editar(resultado);

                    a3Cartera.EditarVencimiento(1);
                    //a3Cartera.VAsString["CodBan"] = "";
                    //a3Cartera.VAsVariant["CodRep"] = null;
                    a3Cartera.VAsVariant["SERIE"] = "    2018";
                    a3Cartera.GuardarVencimiento();
                    CheckEnalce();

                    resultado = a3Cartera.Anade();
                    log.Escribir("Efecto modidifcado con numcartera:" + resultado.ToString());
                    CheckEnalce();
                }
            }
            finally
            {
                a3Cartera.Acabar();
                a3Cartera = null;
            }
        }

        private void btnOportunidades_Click(object sender, EventArgs e)
        {
            Oportunidades opor = new Oportunidades();
            var item = (IOportunidad)opor.Store.Nuevo();
            var datosLin = (ILineaOportunidad)item.Lineas.Nueva();
            var datosOper = (IDatos)item;

            datosOper.AsString["DESCRIPCION"] = "test";
            datosOper.AsString["CODMON"] = "EURO";
            datosOper.AsString["CODREP"] = "1";
            datosOper.AsString["CODPER"] = "       1";
            datosOper.AsFloat["FECHA"] = DateTime.Now.ToOADate();
            datosOper.AsString["ID_ORGANIZACION"] = "5";
            datosOper.AsString["TELEFONO"] = "123.123.123";
            datosOper.AsString["OBSERVACIONES"] = "Observaciones...";

            item.Datos.AsInteger["ID_PROCEDENCIA"] = 1;
            item.Datos.AsInteger["ID_SITUACION"] = 1;
            item.Datos.AsBoolean["P_GENDIS"] = false;
            item.Datos.AsInteger["IMPORTE"] = 666;
            item.Datos.AsInteger["PORCENTAJEEXITO"] = 1;
            item.Datos.AsString["EMAIL"] = "pruebas@WKE.es";
            item.Datos.Clear("FECHAPREVISTA");

            datosLin.Datos.AsString["CODART"] = "21";
            datosLin.Datos.AsString["DESCRIPCION"] = "Linea de oportunidad";
            datosLin.Datos.AsInteger["PRECIO"] = 500;

            opor.Store.Guardar(datosOper);

            log.Escribir("Oportunidad creada");
        }

        private void btnAsientos_Click(object sender, EventArgs e)
        {
            decimal resultado = 0;
            Asiento a3Asiento = null;

            try
            {
                a3Asiento = new Asiento();
                a3Asiento.Iniciar();
                a3Asiento.NuevoNax("N", "1", "GENERAL", "", String.Format("{0:dd/MM/yyyy}", DateTime.Now));
                a3Asiento.AApunteNax("", "GENERADO DESDE A3ERPACTIVEX", "1", "", "", "EURO", "43000000", 100, 100, 0, 0, "", string.Format("{0:dd/MM/yyyy}", DateTime.Now));
                a3Asiento.AApunteNax("", "GENERADO DESDE A3ERPACTIVEX", "1", "", "", "EURO", "57200000", 0, 0, 100, 100, "", string.Format("{0:dd/MM/yyyy}", DateTime.Now));
                resultado = a3Asiento.Anade();

                log.Escribir("Asiento creado con id: " + resultado);
            }
            finally
            {
                a3Asiento.Acabar();
                a3Asiento = null;
            }
        }

        private void btnCobro_Click(object sender, EventArgs e)
        {
            decimal resultado = 0;

            DataTable dtResult = Conexion.ConexionSql.Buscar("Select numcartera, numven, IMPORTEMON from cartera where numcartera = (select max(numcartera) from cartera)");
            OperacionesCartera operaciones;
            try
            {
                operaciones = new OperacionesCartera();
                operaciones.CobrarNax(dtResult.Rows[0].Field<decimal>("NumCartera"), dtResult.Rows[0].Field<Int16>("numven"), true, false, dtResult.Rows[0].Field<decimal>("ImporteMon"),
                    string.Empty, string.Empty, String.Format("{0:dd/MM/yyyy}", DateTime.Now), String.Format("{0:dd/MM/yyyy}", DateTime.Now), "       1", 1.0, string.Empty, 0,
                    string.Empty, string.Empty, string.Empty, string.Empty);
                resultado = dtResult.Rows[0].Field<decimal>("NumCartera");

                log.Escribir("Cobro generado creado con id: " + resultado);
            }
            finally
            {
                operaciones = null;
            }
        }

        private void button2_Click(object sender, EventArgs e)
        {
            decimal resultado = 0;
            Traspaso a3Traspaso = null;

            try
            {
                a3Traspaso = new Traspaso();
                a3Traspaso.Iniciar();

                //if (tipoAlbaran == TipoAlbaran.Traspaso)
                //{
                    a3Traspaso.Nuevo(String.Format("{0:dd/MM/yyyy}", DateTime.Now), "1", "2");
                    a3Traspaso.AsStringCab["Serie"] = "";
                    a3Traspaso.AsVariantCab["TipoCont"] = "2";
                    a3Traspaso.NuevaLinea();
                    a3Traspaso.AsStringLin["CodArt"] = "1";
                    a3Traspaso.AsVariantLin["Unidades"] = 10;
                    a3Traspaso.AsStringLin["DescLin"] = "Descripción modificada desde ActiveX";
                    a3Traspaso.AnadirLinea();
                    a3Traspaso.NuevaLinea();
                    a3Traspaso.AsVariantLin["CodArt"] = "2";
                    a3Traspaso.AsStringLin["DescLin"] = "Descripción2 modificada desde ActiveX";
                    a3Traspaso.AsFloatLin["Unidades"] = 5;
                    a3Traspaso.AnadirLinea();
                    resultado = a3Traspaso.Anade();

                log.Escribir("Albarán traspaso (normal) generado id: " + resultado);

                //}
                //else if (tipoAlbaran == TipoAlbaran.TraspasoUbicacion)
                //{
                a3Traspaso.Nuevo(String.Format("{0:dd/MM/yyyy}", DateTime.Now), "1", String.Empty);
                    a3Traspaso.AsStringCab["Serie"] = "";
                    a3Traspaso.AsVariantCab["TipoCont"] = "2";
                    a3Traspaso.AsStringCab["REUBICACION"] = "T";
                    a3Traspaso.NuevaLineaArt("U1", 1);
                    a3Traspaso.AnadirDetalle(1, string.Empty, "L1", "U1", "U2", String.Format("{0:dd/MM/yyyy}", Convert.ToDateTime("30/12/1899")));
                    a3Traspaso.AnadirLinea();
                    resultado = a3Traspaso.Anade();

                log.Escribir("Albarán traspaso (ubicación) generado id: " + resultado);

                //}
            }
            finally
            {
                a3Traspaso.Acabar();
                a3Traspaso = null;

            }
        }

        private void btnAmortiza_Click(object sender, EventArgs e)
        {
            string resultado = string.Empty;

            try
            {
                Maestro maestro = new Maestro();
                maestro.Iniciar("Amortiza");
                if (maestro.Buscar(new object[] { "       1" }))
                {
                    maestro.Edita();

                    maestro.AsString["NOMAMO"] = "MODIF. A3ERPACTIVEX";
                    if (maestro.AsString["TIPAMOF"] == "L")
                    {
                        if (maestro.AsFloat["PORAMOF"] + 20 < 100)
                            maestro.AsFloat["PORAMOF"] = maestro.AsFloat["PORAMOF"] + 20;
                        else
                            maestro.AsFloat["PORAMOF"] = 10;
                    }
                    maestro.Guarda(true);
                }
                else
                {
                    maestro.Nuevo();
                    maestro.AsString["CODAMO"] = maestro.NuevoCodigoNum();
                    maestro.AsString["NOMAMO"] = "ALTA A3ERPACTIVEX";
                    maestro.AsString["TIPAMOF"] = "L";
                    maestro.AsFloat["PORAMOF"] = 5;
                }

                maestro.Acabar();
                maestro = null;

            }
            catch (Exception ex)
            {
                resultado = ex.Message;
                log.Escribir("Elemento inmovilizado " + ex.Message);
            }
        }
    }


}
