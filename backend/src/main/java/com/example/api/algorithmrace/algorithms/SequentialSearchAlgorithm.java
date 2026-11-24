package com.example.api.algorithmrace.algorithms;

/**
 * Busqueda secuencial: recorre elemento por elemento. O(n).
 * No necesita que el arreglo este ordenado.
 */
public class SequentialSearchAlgorithm {

    /** @return indice de la primera coincidencia, o -1 si no existe */
    public int search(int[] array, int target) {
        for (int i = 0; i < array.length; i++) {
            if (array[i] == target) {
                return i;
            }
        }
        return -1;
    }
}
