using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using a3ERPExtensibilityServicesNET;
using a3ERPActiveXNET;
using ADODB;

namespace a3ERPActiveXPlantillaCL
{
    [ClassInterface(ClassInterfaceType.AutoDual), ComVisible(true)]
    [Guid("134FC3FF-9FBB-43CA-AD82-69FD7BD12D55")]
    public class CursoDll
    {
        public Enlace enlace = null;

        public Connection Connection { get; private set; }
        public Connection SystemConnection { get; private set; }

        /// <summary>
        /// Para ser invocado desde el menu, programas externos, carga automática desde el erp (tabla dlls)
        /// </summary>
        /// <returns></returns>
        public object[] ListaProcedimientos()
        {
            object[] result = { "INICIAR", "FINALIZAR", "ANTESDEGUARDARDOCUMENTOV2", "REPINTAR" };
            return result;
        }

        #region Eventos dlls capturados del ERP
        public bool AntesDeGuardarDocumentoV2(string Documento, decimal IdDoc, ref object Cabecera, ref object Lineas, int Estado)
        {
            bool resultado = true;

            /*
            * Documento =
                        OC: Oferta de compra
                        OV: Oferta de venta
                        PC: Pedido de compra
                        PV: Pedido de venta
                        AC: Albarán de compra
                        AV: Albarán de venta
                        FC: Factura de compra
                        FV: Factura de venta
                        DC: Depósito de compra
                        DV: Depósito de venta
                        TR: Traspasos ºSD
                        RE: Regularización
                        PR: Orden de producción
                        TQ: TPV erp
                         * 

                         * Estado del documento
                         * 0 nuevo
                         * 1 edición
                         * 2 borrado
                         * 3 sirviendo
                         * 4 anulando
                         * 5 desanulando
                         * 
                        */

            if (String.Equals(Documento, "PC", StringComparison.InvariantCultureIgnoreCase))
            {
                object[] RegistroCabecera = ((Cabecera as object[])[1] as object[]);

                string ForPag = GetValor(RegistroCabecera, "FORPAG").ToString();
                string DocPag = GetValor(RegistroCabecera, "DOCPAG").ToString();

                if (String.Equals(DocPag, "LA"))
                {
                    MessageBox.Show(string.Format("No se puede guardar el pedido de compra por el documento de pago asignado {0}", DocPag));
                    resultado = false;
                }

               // CrearAlbaran();

            }
            else
                MessageBox.Show("Evento antesdeguardardocumentov2 se ha ejecutado");
            return resultado;
        }

        private void CrearAlbaran()
        {
            Albaran albaran = new Albaran();
            try
            {
                try
                {
                    albaran.Iniciar();
                    albaran.Nuevo(String.Format("{0:dd/MM/yyyy}", DateTime.Now), "1", true);
                    albaran.NuevaLineaArt("1", 10);
                    albaran.AnadirLinea();
                    albaran.Anade();
                }
                catch (Exception ex)
                {
                    albaran.Cancela();
                }
            }
            finally
            {
                albaran.Acabar();
                albaran = null;
            }

        }

        public bool RePintar(string Tabla)
        {
            MessageBox.Show("Repintando la tabla: " + Tabla);

            if (string.Equals(Tabla, "CLIENTES"))
                return true;
            else
                return false;
        }

        #endregion


        #region Llamadas accesibles una vez el erp está arrancado
        public void Iniciar(string connEmpresaNexus, string connSistemaNexus)
        {
            MessageBox.Show("Arrancando active library1 c#" + Environment.NewLine + connEmpresaNexus);

            enlace = new Enlace();
            enlace.RaiseOnException = true;

            enlace.Iniciar("");

        }

        public void Finalizar()
        {
            MessageBox.Show("Finalizando active library1 c#");
            //NO!!! hay que hacer un enlace.Acabar()

        }
        #endregion

        #region Llamadas desde menu o programas externos
        //Método para llamar a otras opciones desde el menú o desde programas externos
        //En caso de llamarse la opción desde programas externos se rellenará el segundo parametro
        //con la clave del mantenimiento asociado
        public void Opcion(string IdOpcion, string Parametro)
        {
            if (IdOpcion.ToUpper() == "LLAMADATEST")
                LlamadaTest();
        }

        public void LlamadaTest()
        {
            MessageBox.Show("Llamada de prueba desde el menu");
        }
        #endregion

        #region Métodos privados de ayuda
        private object GetValor(object[] Datos, string Campo)
        {
            object result = null;
            for (int i = 1; (i <= (int)Datos[0]); i++)
            {
                object[] item = (Datos[i] as object[]);
                if (item[0].ToString().ToUpper() == Campo.ToUpper())
                    result = item[1];
            }
            return result;
        }

        private void SetValor(ref object[] Datos, string Campo, object value)
        {
            for (int i = 1; (i <= (int)Datos[0]); i++)
            {
                object[] item = (Datos[i] as object[]);
                if (item[0].ToString().ToUpper() == Campo.ToUpper())
                    item[1] = value;
            }
        }
        #endregion

        #region Nuevo método obtener conexion

        private Connection getNewConnection()
        {
            try
            {
                Services services = new Services();
                services.Init(String.Empty);

                return (ADODB.Connection)services.GetDBServices().NewConnection();
            }
            catch (Exception ex)
            {
                MessageBox.Show("No se ha podido crear el enlace de a3ERPExtensibilityServices.", "ERROR", MessageBoxButtons.OK, MessageBoxIcon.Error);
                throw ex;
            }
        }

        private Connection getNewSystemConnection()
        {
            try
            {
                Services services = new Services();
                services.Init(String.Empty);

                return (ADODB.Connection)services.GetDBServices().NewSystemConnection();
            }
            catch (Exception ex)
            {
                MessageBox.Show("No se ha podido crear el enlace de a3ERPExtensibilityServices.", "ERROR", MessageBoxButtons.OK, MessageBoxIcon.Error);
                throw ex;
            }
        }

        #endregion

        #region Conexion ADODB del a3ERPActiveX.Enlace
        private void EjemploObtenerConexionADODB()
        {
            //EMPRESA,SISTEMA,LOGIN
            IEnlace e = new Enlace();
            Connection adocon = e.GetConexionDB("EMPRESA");
            ADODB.Command adocm = new Command();
            adocm.ActiveConnection = adocon;
            adocm.CommandText = "Select * from tarifas";
            object aux = Type.Missing;
            ADODB.Recordset rs = adocm.Execute(out aux, ref aux, 0);
        }
        #endregion
    }
}
