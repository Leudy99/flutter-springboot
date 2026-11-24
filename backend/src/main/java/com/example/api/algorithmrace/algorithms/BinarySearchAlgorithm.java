package com.example.api.algorithmrace.algorithms;

/**
 * Busqueda binaria: descarta la mitad del rango en cada paso. O(log n).
 * REQUIERE que el arreglo ya este ordenado.
 */
public class BinarySearchAlgorithm {

    /** @return indice de una coincidencia, o -1 si no existe */
    public int search(int[] sortedArray, int target) {
        int low = 0;
        int high = sortedArray.length - 1;
        while (low <= high) {
            int middle = low + (high - low) / 2;
            if (sortedArray[middle] == target) {
                return middle;
            }
            if (sortedArray[middle] < target) {
                low = middle + 1;
            } else {
                high = middle - 1;
            }
        }
        return -1;
    }
}
