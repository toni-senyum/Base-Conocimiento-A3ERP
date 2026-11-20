using a3ERPActiveXNET;
using System;

namespace a3ERPActiveXPlantillas
{
    public class LineaDetalleParametros : ILineaDetalleParametros
    {
        public DateTime FechaCaducidad { get; set; }
        public int Linea { get; set; }
        public string Lote { get; set; }
        public string NumeroSerie { get; set; }
        public string Ubicacion { get; set; }
        public double UnidadesStock { get; set; }
        public double UnidadesPrecio { get; set; }
        public double PrcMedio { get; set; }
    }
}
