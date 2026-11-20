using System;
using System.Windows.Forms;

namespace a3ERPActiveXPlantillas
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            if (args.Length >= 3)
            {
                ParametrosMenu.Empresa = args[0];
                ParametrosMenu.Usuario = args[1];
                ParametrosMenu.Password = args[2];
            }

            Application.Run(new Principal());
        }
    }
}
