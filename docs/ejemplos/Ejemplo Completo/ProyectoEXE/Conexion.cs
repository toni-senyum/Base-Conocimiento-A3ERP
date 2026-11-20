using System;

using System.Data.SqlClient;
using System.Data;

namespace a3ERPActiveXPlantillas
{
    internal class Conexion
    {
        private static object syncRoot = new Object();
        static Conexion conexion = null;
        static SqlConnection sqlConexion = null;

        static public Conexion ConexionSql
        {
            get
            {
                if (conexion == null)
                {
                    lock (syncRoot)
                    {
                        conexion = new Conexion();
                    }
                }

                return conexion;
            }
        }

        public void AbrirConexion(string conexionoldb)
        {

            if (sqlConexion == null)
                sqlConexion = new SqlConnection();

            sqlConexion.Close();
            sqlConexion.ConnectionString = conexionoldb;
            sqlConexion.Open();
        }

        public void CerrarConexion()
        {
            if (sqlConexion != null)
                sqlConexion.Close();
        }

        public string GenerarConexion(string conexionErp, string usuario, string password)
        {
            string Usuario = usuario;
            string Servidor = "";
            string BaseDeDatos = "";
            string Password = password;
            string conexion = "Data Source={0};Initial Catalog={1};User Id={2};Password={3}";

            string[] Copia;
            Copia = conexionErp.Split(new Char[] { ';' });
            foreach (string item in Copia)
            {
                string[] items = item.Split(new Char[] { '=' });
                //if (items[0].ToUpper() == "USER ID")
                //    Usuario = items[1];
                //else 
                if (items[0].ToUpper() == "INITIAL CATALOG")
                    BaseDeDatos = items[1];
                else if (items[0].ToUpper() == "DATA SOURCE")
                    Servidor = items[1];
            }

            return string.Format(conexion, Servidor, BaseDeDatos, Usuario, Password);
        }

        public DataTable Buscar(string sql)
        {
            DataTable dt = new DataTable();

            using (SqlDataAdapter adapter = new SqlDataAdapter(sql, sqlConexion))
            {
                adapter.Fill(dt);
            }

            return dt;
        }
    }
}
