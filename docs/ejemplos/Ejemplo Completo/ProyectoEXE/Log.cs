using System.Windows.Forms;

namespace a3ERPActiveXPlantillas
{
    internal class Log
    {
        ListBox _log = null;

        public Log(object log)
        {
            if (log is ListBox)
                _log = (ListBox)log;
        }

        public void Vaciar()
        {
            if (_log == null)
                return;

            _log.Items.Clear();
            Application.DoEvents();
        }

        public void Escribir(string sTexto)
        {
            if (_log == null)
                return;

            if (!string.IsNullOrWhiteSpace(sTexto))
                _log.Items.Add(sTexto);

            if (_log.Items.Count > 15)
                _log.TopIndex = _log.Items.Count - 10;

            Application.DoEvents();
        }
    }
}
